# 📱 Integração Telegram - TaskFlow

## 🎯 Visão Geral

Esta integração permite comunicação **bidirecional** entre o app Flutter TaskFlow e o Telegram, mantendo o Supabase como fonte oficial das mensagens.

**Fluxo:**
```
Telegram <---> Supabase (Edge Functions) <---> Flutter App
```

**Funcionalidades:**
- ✅ Enviar mensagens do app para o Telegram
- ✅ Receber mensagens do Telegram no app
- ✅ Suporte a threads (comunidades e tarefas)
- ✅ Múltiplos modos: DM, grupo simples, grupo com tópicos
- ✅ Suporte a anexos (imagens, vídeos, áudio, documentos)
- ✅ Suporte a localização
- ✅ Edição e exclusão de mensagens

---

## 📋 Pré-requisitos

1. **Bot do Telegram criado** (via [@BotFather](https://t.me/BotFather))
2. **Supabase configurado** com service_role key
3. **Edge Functions habilitadas** no Supabase

---

## 🚀 Configuração Passo a Passo

### 1. Criar Bot no Telegram

1. Abra o Telegram e procure por **@BotFather**
2. Envie `/newbot`
3. Siga as instruções e escolha um nome e username para o bot
4. Você receberá um **Bot Token** (ex: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)
5. **Guarde este token com segurança!**

**Configurações adicionais recomendadas:**
```
/setdescription - Definir descrição do bot
/setabouttext - Texto "Sobre"
/setcommands - Configurar comandos:
  vincular - Vincular conta Telegram ao TaskFlow
  ajuda - Mostrar ajuda
```

### 2. Executar Migration no Supabase

Execute a migration que cria as tabelas necessárias:

```bash
# Via Supabase CLI
supabase db push

# Ou execute manualmente no SQL Editor do Supabase Dashboard
```

Arquivo: `supabase/migrations/20260124_telegram_integration.sql`

**Tabelas criadas:**
- `telegram_identities`: Mapeamento usuário <-> Telegram
- `telegram_subscriptions`: Configuração de espelhamento
- `telegram_delivery_logs`: Log de entregas

### 3. Configurar Variáveis de Ambiente

No **Supabase Dashboard** > **Edge Functions** > **Secrets**, adicione:

```env
TELEGRAM_BOT_TOKEN=seu_token_aqui
TELEGRAM_WEBHOOK_SECRET=sua_senha_secreta_aqui
```

**⚠️ Importante:**
- `TELEGRAM_WEBHOOK_SECRET`: Gere uma senha forte e única (ex: use `openssl rand -hex 32`)
- Estas variáveis são usadas pelas Edge Functions

### 4. Deploy das Edge Functions

```bash
# Instalar Supabase CLI (se ainda não tiver)
npm install -g supabase

# Login
supabase login

# Link com seu projeto
supabase link --project-ref SEU_PROJECT_REF

# Deploy das functions
supabase functions deploy telegram-webhook
supabase functions deploy telegram-send
```

**Verificar deploy:**
```bash
supabase functions list
```

### 5. Configurar Webhook do Telegram

Após o deploy, configure o webhook para o Telegram enviar updates:

```bash
# Substituir pelos seus valores
BOT_TOKEN="seu_token_aqui"
WEBHOOK_URL="https://SEU_PROJECT_REF.supabase.co/functions/v1/telegram-webhook"
WEBHOOK_SECRET="sua_senha_secreta_aqui"

# Configurar webhook
curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{
    \"url\": \"${WEBHOOK_URL}\",
    \"secret_token\": \"${WEBHOOK_SECRET}\",
    \"allowed_updates\": [\"message\", \"edited_message\", \"callback_query\"]
  }"
```

**Verificar webhook:**
```bash
curl "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"
```

### 6. Atualizar Flutter App

As dependências já estão incluídas. Apenas certifique-se de ter:

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^latest
```

---

## 🎮 Como Usar

### No App Flutter

#### 1. Vincular Conta Telegram

1. Abra qualquer chat no app
2. Clique no ícone **Telegram** no AppBar
3. Clique em **"Vincular"**
4. Copie o link gerado
5. Abra o link no Telegram
6. Inicie o bot (`/start`)
7. O bot confirmará a vinculação

#### 2. Ativar Espelhamento

Após vincular:

1. No mesmo dialog de configuração do Telegram
2. Clique em **"+"** (Adicionar espelhamento)
3. Escolha o modo:
   - **Grupo com tópicos**: Melhor para organização (requer supergrupo com fórum ativado)
   - **Grupo simples**: Para grupos normais
   - **Mensagem direta**: Chat privado com o bot
4. Insira o **Chat ID** do grupo/chat
5. (Opcional) Insira o **Topic ID** se usar tópicos
6. Clique em **"Ativar"**

#### 3. Obter Chat ID e Topic ID

**Para obter Chat ID:**
1. Adicione [@userinfobot](https://t.me/userinfobot) ao seu grupo
2. O bot enviará o Chat ID (ex: `-1001234567890`)

**Para obter Topic ID:**
1. Em um grupo com fórum ativado, abra o tópico desejado
2. Veja a URL no app web: `...?topic=123` → `123` é o Topic ID
3. Ou use um bot de informações

### No Telegram

**Enviar mensagens:**
- Digite normalmente no grupo/tópico configurado
- Mensagens aparecem no app em tempo real

**Receber mensagens:**
- Mensagens enviadas no app aparecem automaticamente no Telegram

**Tipos suportados:**
- ✅ Texto
- ✅ Imagens
- ✅ Vídeos
- ✅ Áudios
- ✅ Documentos
- ✅ Localização

---

## 🏗️ Arquitetura

### Estrutura de Dados

```
Comunidades (divisão + segmento)
  └─ Grupos (tarefas)
      └─ Mensagens
```

**Mapeamento:**
- `thread_type`: `"COMMUNITY"` ou `"TASK"`
- `thread_id`: ID da comunidade ou do grupo

### Fluxo de Mensagens

#### App → Telegram

```
1. Usuário envia mensagem no Flutter
2. ChatService.enviarMensagem() persiste no Supabase
3. ChatService chama _enviarParaTelegramAsync()
4. TelegramService verifica se há subscription ativa
5. Se sim, chama Edge Function telegram-send
6. Edge Function envia para Telegram via Bot API
7. Log de entrega é registrado
```

#### Telegram → App

```
1. Usuário envia mensagem no Telegram
2. Telegram chama webhook (telegram-webhook)
3. Edge Function valida secret token
4. Identifica usuário (telegram_identities)
5. Identifica thread (telegram_subscriptions)
6. Persiste mensagem no Supabase (com source="telegram")
7. Realtime do Supabase notifica app
8. Mensagem aparece no chat
```

### Segurança

- ✅ Token do bot **nunca** fica no Flutter
- ✅ Webhook validado com secret token
- ✅ Edge Functions usam service_role (bypass RLS)
- ✅ RLS aplicado nas tabelas de identities e subscriptions
- ✅ Mensagens do Telegram são marcadas com `source="telegram"` para evitar loops

---

## 🧪 Testes

### Checklist de Validação

#### ✅ Vinculação de Conta
- [ ] Link é gerado corretamente
- [ ] Bot recebe comando `/start` e vincula conta
- [ ] Identidade é salva em `telegram_identities`
- [ ] App mostra status "Conta vinculada"

#### ✅ Criação de Subscription
- [ ] Subscription é criada com sucesso
- [ ] Chat ID e Topic ID são salvos corretamente
- [ ] Lista de subscriptions mostra o item criado

#### ✅ Envio App → Telegram
- [ ] Mensagem de texto simples
- [ ] Mensagem com emoji
- [ ] Imagem
- [ ] Vídeo
- [ ] Áudio
- [ ] Documento
- [ ] Localização

#### ✅ Recebimento Telegram → App
- [ ] Mensagem de texto
- [ ] Mensagem com emoji
- [ ] Imagem
- [ ] Vídeo
- [ ] Áudio/voice
- [ ] Documento
- [ ] Localização
- [ ] Edição de mensagem

#### ✅ Edge Cases
- [ ] Usuário não vinculado tenta enviar mensagem no Telegram → Recebe aviso
- [ ] Mensagem enviada em grupo sem subscription → Ignorada
- [ ] Mensagem vinda do Telegram não é reenviada (evitar loop)
- [ ] Anexo muito grande → Tratamento de erro
- [ ] Webhook sem secret token → Rejeitado

### Testes Manuais

**1. Teste básico de envio:**
```bash
# Abrir app, enviar mensagem "Olá Telegram!"
# Verificar se aparece no Telegram
```

**2. Teste básico de recebimento:**
```bash
# No Telegram, enviar mensagem "Olá App!"
# Verificar se aparece no app
```

**3. Teste de imagem:**
```bash
# Enviar foto no app
# Verificar no Telegram
# Enviar foto no Telegram
# Verificar no app
```

**4. Teste de localização:**
```bash
# Compartilhar localização no app
# Verificar no Telegram (deve abrir mapa ao clicar)
```

---

## 🐛 Troubleshooting

### Bot não responde

**Verificar:**
```bash
# Status do webhook
curl "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"
```

**Deve retornar:**
- `url`: URL da Edge Function
- `pending_update_count`: 0 (se houver muitos, limpar)
- `last_error_date`: não deve existir

**Limpar updates pendentes:**
```bash
curl "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook?drop_pending_updates=true"
# Reconfigurar webhook
```

### Mensagens não chegam no app

1. Verificar logs da Edge Function:
   ```bash
   supabase functions logs telegram-webhook
   ```

2. Verificar se usuário está vinculado:
   ```sql
   SELECT * FROM telegram_identities WHERE telegram_user_id = SEU_ID;
   ```

3. Verificar se há subscription ativa:
   ```sql
   SELECT * FROM telegram_subscriptions 
   WHERE telegram_chat_id = SEU_CHAT_ID 
   AND active = true;
   ```

### Mensagens não chegam no Telegram

1. Verificar logs da Edge Function:
   ```bash
   supabase functions logs telegram-send
   ```

2. Verificar delivery logs:
   ```sql
   SELECT * FROM telegram_delivery_logs 
   WHERE status = 'failed' 
   ORDER BY created_at DESC 
   LIMIT 10;
   ```

3. Verificar se bot tem permissão para enviar no grupo:
   - Bot deve ser admin (se for grupo privado)
   - Bot deve ter permissão de enviar mensagens

### Erro "Chat not found"

- Chat ID está incorreto
- Bot foi removido do grupo
- Bot não tem permissão

### Erro "Message thread not found"

- Topic ID está incorreto
- Tópico foi fechado ou deletado
- Grupo não tem fórum ativado (mas mode está como `group_topic`)

---

## 📊 Monitoramento

### Logs úteis

**Edge Functions:**
```bash
# Webhook (recebimento)
supabase functions logs telegram-webhook --limit 50

# Send (envio)
supabase functions logs telegram-send --limit 50
```

**Delivery logs:**
```sql
-- Últimas entregas
SELECT 
  m.conteudo,
  dl.status,
  dl.telegram_chat_id,
  dl.sent_at,
  dl.error_message
FROM telegram_delivery_logs dl
JOIN mensagens m ON m.id = dl.mensagem_id
ORDER BY dl.created_at DESC
LIMIT 20;

-- Taxa de sucesso
SELECT 
  status,
  COUNT(*) as total,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
FROM telegram_delivery_logs
WHERE created_at > now() - interval '24 hours'
GROUP BY status;
```

---

## 🔧 Configurações Avançadas

### Alterar configurações de uma subscription

```dart
await telegramService.updateSubscription(
  subscriptionId,
  settings: {
    'send_notifications': true,
    'send_attachments': false, // Não enviar anexos
    'send_locations': true,
    'bi_directional': true, // Receber do Telegram
  },
);
```

### Desativar temporariamente

```dart
await telegramService.updateSubscription(
  subscriptionId,
  active: false, // Desativar
);
```

---

## 🚀 Próximas Melhorias

- [ ] Comando `/help` no bot
- [ ] Inline buttons para ações rápidas (marcar tarefa como concluída)
- [ ] Notificações inteligentes (apenas menções, por exemplo)
- [ ] Sincronização de leitura (marcar como lida no Telegram quando ler no app)
- [ ] Suporte a threads/replies no Telegram
- [ ] Backup automático de mensagens
- [ ] Analytics de uso

---

## 📞 Suporte

Em caso de dúvidas ou problemas:

1. Verificar esta documentação
2. Consultar logs das Edge Functions
3. Verificar status do webhook no Telegram
4. Verificar tabelas de identities e subscriptions no Supabase

**Contato:** [Seu contato aqui]

---

## 📄 Licença

[Sua licença aqui]
