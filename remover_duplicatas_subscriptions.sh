#!/bin/bash
# ============================================
# REMOVER SUBSCRIPTIONS DUPLICADAS
# ============================================

GRUPO_ID="369377cf-3678-43e2-8314-f4accf58575f"

echo "1. Verificando subscriptions duplicadas para o grupo $GRUPO_ID..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    id,
    thread_type,
    thread_id,
    telegram_chat_id,
    active,
    created_at
FROM telegram_subscriptions
WHERE thread_type = 'TASK' 
  AND thread_id = '$GRUPO_ID'
  AND active = true
ORDER BY created_at;
"

echo ""
echo "2. Removendo duplicatas (mantendo apenas a mais recente)..."
docker exec supabase-db psql -U postgres -d postgres -c "
WITH duplicatas AS (
  SELECT id,
         ROW_NUMBER() OVER (PARTITION BY thread_type, thread_id, telegram_chat_id ORDER BY created_at DESC) as rn
  FROM telegram_subscriptions
  WHERE thread_type = 'TASK' 
    AND thread_id = '$GRUPO_ID'
    AND active = true
)
UPDATE telegram_subscriptions
SET active = false
WHERE id IN (
  SELECT id FROM duplicatas WHERE rn > 1
);
"

echo ""
echo "3. Verificando resultado..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    id,
    thread_type,
    thread_id,
    telegram_chat_id,
    active,
    created_at
FROM telegram_subscriptions
WHERE thread_type = 'TASK' 
  AND thread_id = '$GRUPO_ID'
  AND active = true;
"

echo ""
echo "✅ Duplicatas removidas!"
