# Diagnosticar: Mensagem Enviada mas Não Deletada do Telegram

## Problema
Mensagem foi enviada do Flutter para o Telegram, mas quando deletada no Flutter, não foi deletada do Telegram.

## Possíveis Causas

### 1. Log de Entrega Não Foi Criado
- Mensagem foi enviada para o Telegram
- Mas o log de entrega não foi salvo no banco
- Quando tenta deletar, não encontra o `telegram_message_id`

### 2. Log Criado com Status Diferente de 'sent'
- Log foi criado mas com `status: 'failed'` ou outro
- Código busca apenas logs com `status: 'sent'`
- Não encontra o log e não deleta

### 3. Problema de Timing
- Mensagem foi deletada muito rápido após envio
- Log ainda não foi criado quando tentou deletar

## Diagnóstico

### 1. Verificar Mensagens Recentes Deletadas

```sql
SELECT 
    m.id,
    m.conteudo,
    m.source,
    m.created_at,
    m.deleted_at,
    COUNT(dl.id) as delivery_logs_count,
    STRING_AGG(DISTINCT dl.status::text, ', ') as status_logs,
    MAX(dl.telegram_message_id) as ultimo_telegram_message_id
FROM mensagens m
LEFT JOIN telegram_delivery_logs dl ON dl.mensagem_id = m.id
WHERE m.source = 'app'
  AND m.deleted_at IS NOT NULL
  AND m.created_at > NOW() - INTERVAL '2 hours'
GROUP BY m.id, m.conteudo, m.source, m.created_at, m.deleted_at
ORDER BY m.created_at DESC
LIMIT 10;
```

**O que procurar:**
- Se `delivery_logs_count = 0`: Log não foi criado
- Se `delivery_logs_count > 0` mas `ultimo_telegram_message_id IS NULL`: Log sem message_id
- Se `status_logs` contém 'failed': Log foi criado mas com erro

### 2. Verificar Logs de Entrega Detalhados

```sql
SELECT 
    dl.id,
    dl.mensagem_id,
    dl.telegram_message_id,
    dl.telegram_chat_id,
    dl.status,
    dl.error_message,
    dl.created_at,
    m.conteudo,
    m.deleted_at
FROM telegram_delivery_logs dl
JOIN mensagens m ON m.id = dl.mensagem_id
WHERE dl.mensagem_id IN (
    SELECT id FROM mensagens 
    WHERE source = 'app' 
      AND deleted_at IS NOT NULL 
      AND created_at > NOW() - INTERVAL '2 hours'
)
ORDER BY dl.created_at DESC
LIMIT 20;
```

### 3. Verificar Logs do Servidor

```bash
# Buscar logs de envio da mensagem
journalctl -u telegram-webhook -n 200 --no-pager | grep -E "Mensagem enviada|send-message|telegram_message_id"

# Buscar logs de deleção
journalctl -u telegram-webhook -n 200 --no-pager | grep -E "deleteMessageEverywhere|Encontrados.*log"
```

## Correções Implementadas

### 1. Buscar Logs com Qualquer Status
O código agora busca logs mesmo se não tiverem status 'sent', desde que tenham `telegram_message_id`.

### 2. Logs Detalhados para Diagnóstico
O código agora mostra logs detalhados quando não encontra logs 'sent', ajudando a identificar o problema.

## Próximos Passos

1. Execute as queries SQL acima para identificar o problema
2. Verifique os logs do servidor para ver se o log foi criado
3. Se o log não foi criado, verifique se o envio para Telegram foi bem-sucedido
4. Faça deploy do Node.js atualizado: `.\deploy_nodejs_rapido.ps1`

## Solução Temporária

Se a mensagem está no Telegram mas não tem log de entrega, você pode:

1. **Deletar manualmente no Telegram** (não sincroniza automaticamente)
2. **Criar log manualmente** (se souber o `telegram_message_id`):

```sql
INSERT INTO telegram_delivery_logs (
    mensagem_id,
    telegram_chat_id,
    telegram_topic_id,
    telegram_message_id,
    status
) VALUES (
    '<mensagem_id>',
    -1003878325215,
    19,  -- ou o topic_id correto
    <telegram_message_id>,  -- ID da mensagem no Telegram
    'sent'
);
```

Depois disso, tentar deletar novamente pelo Flutter.
