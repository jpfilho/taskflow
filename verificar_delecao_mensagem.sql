-- Verificar se a mensagem foi deletada
SELECT
    id,
    conteudo,
    deleted_at,
    deleted_by,
    source,
    created_at
FROM mensagens
WHERE id = '6d9af518-bdcf-4cd5-91ed-03ea01baf413';

-- Verificar se o log de entrega ainda existe (deve existir mesmo após soft delete)
SELECT
    dl.id,
    dl.mensagem_id,
    dl.telegram_message_id,
    dl.telegram_chat_id,
    dl.status,
    dl.created_at
FROM telegram_delivery_logs dl
WHERE dl.mensagem_id = '6d9af518-bdcf-4cd5-91ed-03ea01baf413';
