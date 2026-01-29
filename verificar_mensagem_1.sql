-- Verificar se a mensagem "1" foi deletada no banco
SELECT
    id,
    conteudo,
    deleted_at,
    deleted_by,
    source,
    created_at
FROM mensagens
WHERE id = '1dfb397c-950d-4356-849b-3bdd7ff860e3';

-- Verificar log de entrega
SELECT
    dl.id,
    dl.mensagem_id,
    dl.telegram_message_id,
    dl.telegram_chat_id,
    dl.status,
    dl.created_at
FROM telegram_delivery_logs dl
WHERE dl.mensagem_id = '1dfb397c-950d-4356-849b-3bdd7ff860e3';
