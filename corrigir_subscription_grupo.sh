#!/bin/bash
# ============================================
# VERIFICAR E CORRIGIR SUBSCRIPTIONS
# ============================================

GRUPO_ID="369377cf-3678-43e2-8314-f4accf58575f"

echo "1. Verificando se existe subscription para o grupo $GRUPO_ID..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    id,
    thread_type,
    thread_id,
    telegram_chat_id,
    active
FROM telegram_subscriptions
WHERE thread_type = 'TASK' 
  AND thread_id = '$GRUPO_ID'
  AND active = true;
"

echo ""
echo "2. Verificando todas as subscriptions ativas para este chat_id..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    id,
    thread_type,
    thread_id,
    telegram_chat_id,
    active
FROM telegram_subscriptions
WHERE telegram_chat_id = -1003721115749
  AND active = true
ORDER BY created_at DESC;
"

echo ""
echo "3. Criando subscription para o grupo correto (se não existir)..."
docker exec supabase-db psql -U postgres -d postgres -c "
INSERT INTO telegram_subscriptions (
    thread_type,
    thread_id,
    mode,
    telegram_chat_id,
    telegram_topic_id,
    active,
    created_by,
    created_at
)
SELECT 
    'TASK',
    '$GRUPO_ID',
    'group_plain',
    -1003721115749,
    NULL,
    true,
    (SELECT id FROM executores LIMIT 1),
    NOW()
WHERE NOT EXISTS (
    SELECT 1 
    FROM telegram_subscriptions 
    WHERE thread_type = 'TASK' 
      AND thread_id = '$GRUPO_ID' 
      AND active = true
);
"

echo ""
echo "4. Verificando subscription criada..."
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
