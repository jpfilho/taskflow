#!/bin/bash
# ============================================
# ATUALIZAR CHAT ID - FORÇA BRUTA
# ============================================

echo "Atualizando Chat ID de -5127731041 para -1003721115749..."

docker exec supabase-db psql -U postgres -d postgres -c "
UPDATE telegram_subscriptions
SET telegram_chat_id = -1003721115749,
    updated_at = NOW()
WHERE telegram_chat_id = -5127731041;
"

echo ""
echo "Verificando resultado..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    telegram_chat_id,
    COUNT(*) as total,
    COUNT(CASE WHEN active = true THEN 1 END) as ativas
FROM telegram_subscriptions
GROUP BY telegram_chat_id;
"
