-- ============================================
-- MIGRATION: CORRIGIR RLS TELEGRAM_COMMUNITIES V2
-- ============================================
-- Versão mais robusta - remove TODAS as políticas e recria
-- Data: 2026-01-25

-- 1. Desabilitar RLS temporariamente para limpeza
ALTER TABLE telegram_communities DISABLE ROW LEVEL SECURITY;

-- 2. Remover TODAS as políticas existentes (usando CASCADE se necessário)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'telegram_communities') LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON telegram_communities';
    END LOOP;
END $$;

-- 3. Remover políticas manualmente (caso o loop acima não capture todas)
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Allow read telegram_communities" ON telegram_communities;
DROP POLICY IF EXISTS "Allow select for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Allow update for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Allow delete for authenticated users" ON telegram_communities;

-- 4. Reabilitar RLS
ALTER TABLE telegram_communities ENABLE ROW LEVEL SECURITY;

-- 5. Criar políticas novas e permissivas
-- IMPORTANTE: Como o Flutter usa autenticação customizada, vamos permitir para anon também
-- SELECT: Permitir leitura para todos (authenticated e anon)
CREATE POLICY "telegram_communities_select_policy"
ON telegram_communities FOR SELECT
TO public
USING (true);

-- INSERT: Permitir inserção para authenticated E anon (devido à autenticação customizada)
CREATE POLICY "telegram_communities_insert_policy"
ON telegram_communities FOR INSERT
TO public
WITH CHECK (true);

-- UPDATE: Permitir atualização para authenticated E anon
CREATE POLICY "telegram_communities_update_policy"
ON telegram_communities FOR UPDATE
TO public
USING (true)
WITH CHECK (true);

-- DELETE: Permitir deleção para authenticated E anon
CREATE POLICY "telegram_communities_delete_policy"
ON telegram_communities FOR DELETE
TO public
USING (true);

-- 6. Verificar se as políticas foram criadas
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'telegram_communities';
    
    RAISE NOTICE 'Total de políticas criadas para telegram_communities: %', policy_count;
END $$;
