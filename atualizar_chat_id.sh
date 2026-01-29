#!/bin/bash
# ============================================
# ATUALIZAR CHAT ID DAS SUBSCRIPTIONS
# ============================================

CHAT_ID_ANTIGO="-5127731041"
CHAT_ID_NOVO="-1003721115749"

echo "Atualizando Chat ID das subscriptions..."
echo "  Antigo: $CHAT_ID_ANTIGO"
echo "  Novo: $CHAT_ID_NOVO"
echo ""

docker exec supabase-db psql -U postgres -d postgres << EOF
-- Atualizar todas as subscriptions com o novo Chat ID
UPDATE telegram_subscriptions
SET telegram_chat_id = $CHAT_ID_NOVO,
    updated_at = NOW()
WHERE telegram_chat_id = $CHAT_ID_ANTIGO;

-- Verificar atualizacao
SELECT 
    COUNT(*) as total_atualizadas,
    telegram_chat_id,
    active
FROM telegram_subscriptions
WHERE telegram_chat_id = $CHAT_ID_NOVO
GROUP BY telegram_chat_id, active;
EOF

echo ""
echo "Chat ID atualizado com sucesso!"
