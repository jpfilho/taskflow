-- Diagnosticar mensagem que foi enviada mas não foi deletada do Telegram

-- 1. Encontrar mensagens recentes do Flutter (source='app') que foram deletadas
-- mas ainda estão no Telegram
SELECT 
    m.id,
    m.conteudo,
    m.source,
    m.created_at,
    m.deleted_at,
    m.deleted_by,
    COUNT(dl.id) as delivery_logs_count,
    STRING_AGG(DISTINCT dl.status::text, ', ') as status_logs,
    MAX(dl.telegram_message_id) as ultimo_telegram_message_id
FROM mensagens m
LEFT JOIN telegram_delivery_logs dl ON dl.mensagem_id = m.id
WHERE m.source = 'app'
  AND m.deleted_at IS NOT NULL
  AND m.created_at > NOW() - INTERVAL '2 hours'
GROUP BY m.id, m.conteudo, m.source, m.created_at, m.deleted_at, m.deleted_by
ORDER BY m.created_at DESC
LIMIT 20;

-- 2. Verificar logs de entrega com status diferente de 'sent'
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
