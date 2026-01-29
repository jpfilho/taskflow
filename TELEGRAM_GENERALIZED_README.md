# Integração Telegram Generalizada - TaskFlow

## 📋 Visão Geral

Esta integração permite que **qualquer tarefa** do Flutter tenha seu chat espelhado no Telegram, usando o modelo:
- **1 Supergrupo por Comunidade** (divisão + segmento)
- **1 Tópico por Tarefa** dentro do supergrupo

## 🏗️ Arquitetura

```
Flutter App
    ↓ (envia mensagem)
Supabase (mensagens table)
    ↓ (via /send-message)
Node.js Gateway
    ↓ (ensureTaskTopic)
Telegram Supergrupo + Tópico
```

```
Telegram Supergrupo
    ↓ (webhook)
Node.js Gateway
    ↓ (identifyTaskFromTopic)
Supabase (mensagens table)
    ↓ (realtime)
Flutter App
```

## 📊 Estrutura de Dados

### Tabelas Principais

1. **`telegram_communities`**: Mapeia comunidades → supergrupos Telegram
2. **`telegram_task_topics`**: Mapeia tarefas → tópicos dentro dos supergrupos
3. **`telegram_delivery_logs`**: Logs de entrega de mensagens

### Relacionamentos

- `comunidades` (divisão + segmento) → `telegram_communities` (supergrupo)
- `tasks` → `grupos_chat` → `telegram_task_topics` (tópico)

## 🚀 Setup Inicial

### 1. Executar Migration SQL

```bash
# No Supabase SQL Editor ou via psql
psql -U postgres -d postgres -f supabase/migrations/20260124_telegram_generalize.sql
```

### 2. Configurar Supergrupo para Comunidade

Para cada comunidade que você quer integrar:

```bash
# Via endpoint admin
curl -X POST https://api.taskflowv3.com.br/admin/communities/{community_id}/telegram-chat \
  -H "Content-Type: application/json" \
  -d '{"telegram_chat_id": -1003721115749}'
```

**Como obter o Chat ID:**
- Adicione o bot ao supergrupo
- Torne o bot administrador
- Use `@getidsbot` ou veja os logs do webhook

### 3. Habilitar Forum Topics no Supergrupo

No Telegram:
1. Vá em **Configurações do Grupo** → **Tipo**
2. Selecione **Fórum** (Topics)
3. Confirme a conversão

### 4. Tornar o Bot Administrador

O bot precisa ser admin para:
- Criar tópicos (`createForumTopic`)
- Enviar mensagens em tópicos

### 5. Deploy do Servidor Node.js

```bash
# Copiar arquivo generalizado
scp telegram-webhook-server-generalized.js root@212.85.0.249:/root/telegram-webhook/

# No servidor
cd /root/telegram-webhook
npm install pg  # Instalar dependência pg
pm2 restart telegram-webhook
# ou
systemctl restart telegram-webhook
```

## 🔧 Endpoints

### `/send-message` (Flutter → Telegram)
Recebe mensagem do Flutter e envia para o tópico correto.

**Request:**
```json
{
  "mensagem_id": "uuid",
  "thread_type": "TASK",
  "thread_id": "grupo_id"  // grupos_chat.id
}
```

### `/telegram-webhook` (Telegram → Supabase)
Recebe updates do Telegram e insere no Supabase.

### `/admin/communities/:id/telegram-chat` (Admin)
Cadastra supergrupo para uma comunidade.

**Request:**
```json
{
  "telegram_chat_id": -1003721115749
}
```

### `/tasks/:id/ensure-topic` (Admin)
Garante que uma tarefa tem tópico (cria se não existir).

## 🔄 Fluxo de Funcionamento

### Envio Flutter → Telegram

1. Usuário envia mensagem no Flutter
2. Flutter salva em `mensagens` (source='app')
3. Flutter chama `/send-message` com `grupo_id`
4. Node.js:
   - Busca `task_id` do `grupo_id`
   - Chama `ensureTaskTopic(task_id)` (cria tópico se necessário)
   - Envia mensagem para o tópico

### Recebimento Telegram → Flutter

1. Usuário envia mensagem no tópico do Telegram
2. Telegram envia webhook para `/telegram-webhook`
3. Node.js:
   - Identifica tarefa via `identifyTaskFromTopic(chatId, topicId)`
   - Valida usuário vinculado
   - Insere mensagem em `mensagens` (source='telegram')
4. Flutter recebe via Realtime

## 📝 Notas Importantes

- **Tópicos são criados automaticamente** na primeira mensagem de uma tarefa
- **Supergrupos devem ser cadastrados manualmente** (uma vez por comunidade)
- O bot precisa ser **admin** do supergrupo
- O supergrupo precisa estar configurado como **Fórum** (Topics habilitado)

## 🧪 Testes

### Checklist

- [ ] Criar 3 tarefas na mesma comunidade → 3 tópicos no mesmo supergrupo
- [ ] Criar 2 tarefas em comunidades diferentes → tópicos em supergrupos diferentes
- [ ] Mensagem no Flutter → aparece no tópico correto
- [ ] Mensagem no tópico → aparece no chat correto do Flutter
- [ ] Usuário não vinculado → mensagem bloqueada
- [ ] Logs registrados em `telegram_delivery_logs`

## 🔍 Troubleshooting

### Tópico não é criado
- Verificar se supergrupo está cadastrado em `telegram_communities`
- Verificar se bot é admin
- Verificar se supergrupo tem Topics habilitado

### Mensagem não aparece no Telegram
- Verificar logs do servidor Node.js
- Verificar `telegram_delivery_logs`
- Verificar se `ensureTaskTopic` retornou sucesso

### Mensagem do Telegram não aparece no Flutter
- Verificar se usuário está vinculado (`telegram_identities`)
- Verificar se tópico está mapeado (`telegram_task_topics`)
- Verificar logs do webhook

## 📚 Migração do Sistema Antigo

O sistema antigo usava `telegram_subscriptions` com mapeamento fixo. O novo sistema:
- Usa `telegram_task_topics` (mapeamento automático)
- Cria tópicos sob demanda
- Não requer configuração manual por tarefa

**Compatibilidade:** O código antigo ainda funciona, mas é recomendado migrar para o novo modelo.
