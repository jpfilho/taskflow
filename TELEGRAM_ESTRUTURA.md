# 🏗️ ESTRUTURA TELEGRAM - TASKFLOW

## 📊 Arquitetura Recomendada

### No Supabase/Flutter:
```
Comunidades (Divisão + Segmento)
  └─ Grupos (1 por tarefa)
      └─ Mensagens
```

### No Telegram (OPÇÃO 1 - RECOMENDADA):
```
Supergrupo por Comunidade
  └─ Tópicos (1 por tarefa)
      └─ Mensagens
```

---

## 🔧 Implementação

### Passo 1: Criar Supergrupo no Telegram

1. **Criar Supergrupo:**
   - Abra o Telegram
   - Criar Novo Grupo
   - Adicione pelo menos 1 membro
   - Menu → "Converter para Supergrupo"
   - Nome: "Divisão A - Segmento 1" (ou nome da comunidade)

2. **Habilitar Tópicos:**
   - Configurações do Grupo
   - "Tipo de Grupo" → "Tópicos"
   - Ativar tópicos

3. **Adicionar o Bot:**
   - Adicionar Membro
   - Buscar: `@TaskFlow_chat_bot`
   - Tornar administrador (para criar tópicos)

4. **Obter Chat ID:**
   - Execute: `.\obter_chat_id_rapido.ps1`
   - Anote o Chat ID (número negativo)

### Passo 2: Criar Tópicos por Tarefa

#### Opção A: Manual (via Telegram)
1. No supergrupo, criar novo tópico
2. Nome do tópico = Nome da tarefa
3. Enviar uma mensagem no tópico
4. Obter Topic ID dos logs

#### Opção B: Automático (via API)
```powershell
.\criar_topico_tarefa.ps1
```

### Passo 3: Criar Subscriptions

Para cada tarefa, criar uma subscription:

```sql
INSERT INTO telegram_subscriptions (
    thread_type,
    thread_id,           -- ID do grupo (tarefa) no Supabase
    mode,
    telegram_chat_id,    -- ID do supergrupo
    telegram_topic_id,   -- ID do tópico
    active
) VALUES (
    'TASK',
    'uuid-da-tarefa',
    'group_topic',       -- Modo com tópicos
    -1001234567890,      -- Chat ID do supergrupo
    123,                 -- Topic ID do tópico
    true
);
```

---

## 📋 Estrutura Final

### Exemplo: Regional São Paulo

**Supabase:**
```
Comunidade: Divisão A - Segmento Comercial
  ├─ Grupo: Tarefa "Venda Q1 2026"
  ├─ Grupo: Tarefa "Venda Q2 2026"
  └─ Grupo: Tarefa "Prospecção Cliente X"
```

**Telegram:**
```
Supergrupo: "Divisão A - Comercial"
  ├─ Tópico: "Venda Q1 2026"
  ├─ Tópico: "Venda Q2 2026"
  └─ Tópico: "Prospecção Cliente X"
```

**Subscriptions:**
| Tarefa Supabase | Chat ID Telegram | Topic ID | Status |
|-----------------|------------------|----------|--------|
| uuid-venda-q1   | -1001234567890   | 10       | ✅     |
| uuid-venda-q2   | -1001234567890   | 11       | ✅     |
| uuid-prospeccao | -1001234567890   | 12       | ✅     |

---

## 🎯 Fluxo de Mensagens

### App → Telegram:
1. Usuário envia mensagem no chat da "Tarefa Venda Q1"
2. `chat_service.dart` salva no Supabase
3. `_enviarParaTelegramAsync()` chama `telegram_service.dart`
4. Busca subscription: thread_id = tarefa
5. Envia para Telegram: chat_id + topic_id
6. Mensagem aparece no tópico correto

### Telegram → App:
1. Usuário envia mensagem no tópico "Venda Q1"
2. Webhook recebe: chat_id + topic_id
3. `telegram-webhook-server.js` busca subscription
4. Identifica thread_id (tarefa)
5. Salva mensagem no Supabase
6. Realtime atualiza o Flutter

---

## ⚙️ Scripts Disponíveis

| Script | Função |
|--------|--------|
| `obter_chat_id_rapido.ps1` | Obter Chat ID do supergrupo |
| `criar_topico_tarefa.ps1` | Criar tópico via API |
| `criar_subscription_manual.ps1` | Criar subscription (manual) |
| `criar_subscription_auto.ps1` | Criar subscriptions em massa |
| `verificar_mensagens_banco.ps1` | Verificar mensagens |
| `testar_webhook.ps1` | Testar webhook |

---

## 🚀 Início Rápido

### Para 1 Tarefa (Teste):

```powershell
# 1. Obter Chat ID
.\obter_chat_id_rapido.ps1

# 2. Criar subscription
.\criar_subscription_manual.ps1

# 3. Testar
.\testar_webhook.ps1
```

### Para Múltiplas Tarefas:

```powershell
# Criar subscriptions em massa
.\criar_subscription_auto.ps1
```

---

## 📝 Notas Importantes

1. **Permissões:**
   - Bot precisa ser **administrador** do supergrupo
   - Permissão para criar e gerenciar tópicos

2. **Limites do Telegram:**
   - Máximo de tópicos por grupo: ilimitado (praticamente)
   - Recomendado: até 50-100 tópicos por supergrupo

3. **Organização:**
   - 1 Supergrupo = 1 Comunidade
   - Se tiver muitas tarefas, considere dividir por regional/divisão

4. **Escalabilidade:**
   - Para 10+ comunidades: 10+ supergrupos
   - Para 100+ tarefas: organizar em múltiplos supergrupos
