-- ============================================
-- MIGRATION: CORRIGIR RLS TELEGRAM_COMMUNITIES
-- ============================================
-- Corrigir políticas RLS para permitir upsert via Flutter
-- Data: 2026-01-25

-- 1. Remover todas as políticas existentes
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON telegram_communities;
DROP POLICY IF EXISTS "Allow read telegram_communities" ON telegram_communities;

-- 2. Criar políticas mais permissivas para usuários autenticados
-- SELECT: Permitir leitura para todos autenticados
CREATE POLICY "Allow select for authenticated users"
ON telegram_communities FOR SELECT
TO authenticated
USING (true);

-- INSERT: Permitir inserção para todos autenticados
CREATE POLICY "Allow insert for authenticated users"
ON telegram_communities FOR INSERT
TO authenticated
WITH CHECK (true);

-- UPDATE: Permitir atualização para todos autenticados
CREATE POLICY "Allow update for authenticated users"
ON telegram_communities FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- DELETE: Permitir deleção para todos autenticados
CREATE POLICY "Allow delete for authenticated users"
ON telegram_communities FOR DELETE
TO authenticated
USING (true);

-- 3. Verificar se RLS está habilitado
ALTER TABLE telegram_communities ENABLE ROW LEVEL SECURITY;

-- 4. Comentário
COMMENT ON POLICY "Allow select for authenticated users" ON telegram_communities IS 'Permite leitura para todos usuários autenticados';
COMMENT ON POLICY "Allow insert for authenticated users" ON telegram_communities IS 'Permite inserção para todos usuários autenticados (usado pelo formulário Flutter)';
COMMENT ON POLICY "Allow update for authenticated users" ON telegram_communities IS 'Permite atualização para todos usuários autenticados (usado pelo formulário Flutter)';
COMMENT ON POLICY "Allow delete for authenticated users" ON telegram_communities IS 'Permite deleção para todos usuários autenticados';
