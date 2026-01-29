-- 1. Verificar se existe log de entrega para message_id 63 (mesmo se mensagem foi deletada)
SELECT 
    dl.id,
    dl.mensagem_id,
    dl.telegram_message_id,
    dl.telegram_chat_id,
    dl.status,
    dl.created_at
FROM telegram_delivery_logs dl
WHERE dl.telegram_message_id = 63
  AND dl.telegram_chat_id = -1003878325215;

-- 2. Se encontrar o mensagem_id, verificar a mensagem (mesmo se deletada)
-- (Execute a query acima primeiro e use o mensagem_id retornado)

-- 3. Verificar mensagens recentes enviadas para o Telegram
SELECT 
    m.id,
    m.conteudo,
    m.source,
    m.deleted_at,
    m.created_at,
    dl.telegram_message_id,
    dl.telegram_chat_id,
    dl.status
FROM mensagens m
JOIN telegram_delivery_logs dl ON dl.mensagem_id = m.id
WHERE dl.telegram_chat_id = -1003878325215
  AND dl.status = 'sent'
  AND m.created_at > NOW() - INTERVAL '1 hour'
ORDER BY m.created_at DESC
LIMIT 10;
