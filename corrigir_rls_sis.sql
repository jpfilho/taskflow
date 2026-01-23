-- ============================================
-- SQL PARA CORRIGIR POLÍTICAS RLS DA TABELA SIS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Remover todas as políticas existentes
DROP POLICY IF EXISTS "sis_select_policy" ON sis;
DROP POLICY IF EXISTS "sis_insert_policy" ON sis;
DROP POLICY IF EXISTS "sis_update_policy" ON sis;
DROP POLICY IF EXISTS "sis_delete_policy" ON sis;

DROP POLICY IF EXISTS "Vínculos tasks_sis são visíveis para todos" ON tasks_sis;
DROP POLICY IF EXISTS "Apenas autenticados podem inserir vínculos tasks_sis" ON tasks_sis;
DROP POLICY IF EXISTS "Apenas autenticados podem deletar vínculos tasks_sis" ON tasks_sis;

-- Habilitar RLS na tabela sis
ALTER TABLE sis ENABLE ROW LEVEL SECURITY;

-- Políticas para sis: permitir todas as operações
-- (Ajuste conforme suas necessidades de segurança)
CREATE POLICY "Permitir todas as operações em sis" ON sis
  FOR ALL USING (true) WITH CHECK (true);

-- Habilitar RLS na tabela tasks_sis
ALTER TABLE tasks_sis ENABLE ROW LEVEL SECURITY;

-- Políticas para tasks_sis: permitir todas as operações
CREATE POLICY "Permitir todas as operações em tasks_sis" ON tasks_sis
  FOR ALL USING (true) WITH CHECK (true);

-- Verificar se as políticas foram criadas
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
WHERE tablename IN ('sis', 'tasks_sis')
ORDER BY tablename, policyname;
