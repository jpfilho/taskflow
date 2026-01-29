#!/bin/bash
# ============================================
# CRIAR SUBSCRIPTION TELEGRAM
# ============================================

CHAT_ID="$1"
GRUPO_ID="$2"

if [ -z "$CHAT_ID" ] || [ -z "$GRUPO_ID" ]; then
    echo "Erro: parametros faltando!"
    echo "Uso: $0 <chat_id> <grupo_id>"
    exit 1
fi

echo "Criando subscription..."
echo "  Chat ID: $CHAT_ID"
echo "  Grupo ID: $GRUPO_ID"
echo ""

docker exec supabase-db psql -U postgres -d postgres << EOF
INSERT INTO telegram_subscriptions (
    thread_type,
    thread_id,
    mode,
    telegram_chat_id,
    telegram_topic_id,
    active
) VALUES (
    'TASK',
    '$GRUPO_ID',
    'group_plain',
    $CHAT_ID,
    NULL,
    true
) ON CONFLICT (thread_type, thread_id, telegram_chat_id, telegram_topic_id)
DO UPDATE SET
    active = true,
    updated_at = NOW()
RETURNING id;

-- Verificar subscription criada
SELECT 
    ts.id,
    ts.thread_type,
    ts.telegram_chat_id,
    ts.active,
    gc.tarefa_nome
FROM telegram_subscriptions ts
LEFT JOIN grupos_chat gc ON gc.id = ts.thread_id
WHERE ts.telegram_chat_id = $CHAT_ID;
EOF

echo ""
echo "Subscription criada com sucesso!"
