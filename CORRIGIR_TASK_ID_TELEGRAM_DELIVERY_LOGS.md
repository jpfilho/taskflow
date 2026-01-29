# Correção: Remoção de `task_id` dos Inserts de `telegram_delivery_logs`

## Problema Identificado

O código estava tentando inserir `task_id` na tabela `telegram_delivery_logs`, mas essa coluna **não existe** na tabela.

**Erro nos logs:**
```
Could not find the 'task_id' column of 'telegram_delivery_logs' in the schema cache
```

**Schema Real da Tabela:**
A tabela `telegram_delivery_logs` tem as seguintes colunas:
- `id` (UUID)
- `mensagem_id` (UUID)
- `subscription_id` (UUID) - opcional
- `status` (TEXT)
- `attempt_count` (INTEGER)
- `telegram_chat_id` (BIGINT)
- `telegram_message_id` (INTEGER)
- `telegram_topic_id` (INTEGER)
- `error_code` (TEXT) - opcional
- `error_message` (TEXT) - opcional
- `created_at` (TIMESTAMPTZ)
- `sent_at` (TIMESTAMPTZ) - opcional
- `failed_at` (TIMESTAMPTZ) - opcional
- `request_payload` (JSONB) - opcional
- `response_payload` (JSONB) - opcional

**NÃO TEM `task_id`!**

## Correções Implementadas

### 1. Função Helper `insertDeliveryLog`
Criada função centralizada que **nunca inclui `task_id`**:

```javascript
async function insertDeliveryLog(logData) {
  const { mensagem_id, telegram_chat_id, telegram_topic_id, telegram_message_id, status, error_message, error_code } = logData;
  
  // Construir payload SEM task_id (coluna não existe na tabela)
  const logPayload = {
    mensagem_id,
    telegram_chat_id,
    telegram_topic_id,
    telegram_message_id,
    status,
  };
  
  if (error_message) {
    logPayload.error_message = error_message;
  }
  
  if (error_code) {
    logPayload.error_code = error_code;
  }
  
  // ... insert no Supabase
}
```

### 2. Substituição de Todos os Inserts Diretos
Todos os inserts diretos de `telegram_delivery_logs` foram substituídos para usar a função helper:

**Antes:**
```javascript
await supabase.from('telegram_delivery_logs').insert({
  mensagem_id: mensagem_id,
  task_id: taskId,  // ❌ Coluna não existe!
  telegram_chat_id: topic.telegram_chat_id,
  telegram_topic_id: topic.telegram_topic_id,
  telegram_message_id: telegramMessageId,
  status: 'sent',
});
```

**Depois:**
```javascript
await insertDeliveryLog({
  mensagem_id: mensagem_id,
  telegram_chat_id: topic.telegram_chat_id,
  telegram_topic_id: topic.telegram_topic_id,
  telegram_message_id: telegramMessageId,
  status: 'sent',
});
```

## Locais Corrigidos

1. ✅ Envio de mensagem de texto (linha ~1689)
2. ✅ Envio de mensagem com mídia (linha ~1532)
3. ✅ Erro ao enviar mensagem (múltiplos locais)
4. ✅ Processamento de mensagem do Telegram (linha ~2420)

## Próximos Passos

1. **Fazer deploy do Node.js atualizado:**
   ```powershell
   .\deploy_nodejs_rapido.ps1
   ```

2. **Testar com uma nova mensagem:**
   - Enviar mensagem do Flutter
   - Verificar logs do servidor: `journalctl -u telegram-webhook -f`
   - Procurar por: `✅ [send-message] Log de entrega salvo com sucesso`
   - **NÃO deve mais aparecer erro de `task_id`**

3. **Verificar se o log foi criado:**
   ```sql
   SELECT * FROM telegram_delivery_logs 
   WHERE mensagem_id = '<id_da_mensagem>'
   ORDER BY created_at DESC;
   ```

4. **Testar deleção:**
   - Deletar mensagem no Flutter
   - Verificar se foi deletada no Telegram também

## Resultado Esperado

Após o deploy:
- ✅ Logs de entrega serão criados com sucesso
- ✅ Mensagens deletadas no Flutter serão deletadas no Telegram
- ✅ Não haverá mais erros de `task_id` nos logs
