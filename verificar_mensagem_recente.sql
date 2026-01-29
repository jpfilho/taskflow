-- Verificar mensagens recentes enviadas do Flutter (source='app')
-- que foram enviadas para o Telegram mas podem não ter log de entrega

SELECT 
    m.id,
    m.conteudo,
    m.source,
    m.created_at,
    m.deleted_at,
    COUNT(dl.id) as delivery_logs_count,
    MAX(dl.telegram_message_id) as ultimo_telegram_message_id,
    MAX(dl.status) as ultimo_status
FROM mensagens m
LEFT JOIN telegram_delivery_logs dl ON dl.mensagem_id = m.id
WHERE m.source = 'app'
  AND m.created_at > NOW() - INTERVAL '1 hour'
  AND m.deleted_at IS NOT NULL  -- Mensagens deletadas recentemente
GROUP BY m.id, m.conteudo, m.source, m.created_at, m.deleted_at
ORDER BY m.created_at DESC
LIMIT 10;

-- Verificar se há mensagens deletadas sem log de entrega
SELECT 
    m.id,
    m.conteudo,
    m.source,
    m.created_at,
    m.deleted_at,
    m.deleted_by
FROM mensagens m
LEFT JOIN telegram_delivery_logs dl ON dl.mensagem_id = m.id
WHERE m.source = 'app'
  AND m.deleted_at IS NOT NULL
  AND dl.id IS NULL  -- Sem log de entrega
  AND m.created_at > NOW() - INTERVAL '1 hour'
ORDER BY m.created_at DESC
LIMIT 10;
