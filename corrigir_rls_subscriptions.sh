#!/bin/bash
# ============================================
# VERIFICAR E CORRIGIR RLS DA TABELA telegram_subscriptions
# ============================================

echo "1. Verificando políticas RLS atuais..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'telegram_subscriptions';
"

echo ""
echo "2. Verificando se RLS está habilitado..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'telegram_subscriptions';
"

echo ""
echo "3. Removendo políticas antigas (se existirem)..."
docker exec supabase-db psql -U postgres -d postgres -c "
DROP POLICY IF EXISTS \"Users can read active subscriptions\" ON telegram_subscriptions;
DROP POLICY IF EXISTS \"Users can read their own subscriptions\" ON telegram_subscriptions;
DROP POLICY IF EXISTS \"telegram_subscriptions_select_policy\" ON telegram_subscriptions;
"

echo ""
echo "4. Criando política RLS para permitir leitura de subscriptions ativas..."
docker exec supabase-db psql -U postgres -d postgres -c "
CREATE POLICY \"Allow read active subscriptions\"
ON telegram_subscriptions
FOR SELECT
USING (active = true);
"

echo ""
echo "5. Verificando se a política foi criada..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'telegram_subscriptions';
"

echo ""
echo "6. Testando query como usuário anon (simulando Flutter)..."
docker exec supabase-db psql -U postgres -d postgres -c "
SET ROLE anon;
SELECT COUNT(*) as total_subscriptions_ativas
FROM telegram_subscriptions
WHERE thread_type = 'TASK' 
  AND thread_id = '369377cf-3678-43e2-8314-f4accf58575f'
  AND active = true;
RESET ROLE;
"
