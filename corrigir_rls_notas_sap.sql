-- ============================================
-- SQL PARA CORRIGIR POLÍTICAS RLS DA TABELA NOTAS_SAP
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Remover todas as políticas existentes
DROP POLICY IF EXISTS "Notas SAP são visíveis para todos" ON notas_sap;
DROP POLICY IF EXISTS "Apenas autenticados podem inserir notas SAP" ON notas_sap;
DROP POLICY IF EXISTS "Apenas autenticados podem atualizar notas SAP" ON notas_sap;
DROP POLICY IF EXISTS "Apenas autenticados podem deletar notas SAP" ON notas_sap;

DROP POLICY IF EXISTS "Vínculos tasks_notas_sap são visíveis para todos" ON tasks_notas_sap;
DROP POLICY IF EXISTS "Apenas autenticados podem inserir vínculos tasks_notas_sap" ON tasks_notas_sap;
DROP POLICY IF EXISTS "Apenas autenticados podem deletar vínculos tasks_notas_sap" ON tasks_notas_sap;

-- Políticas para notas_sap: permitir todas as operações
-- (Ajuste conforme suas necessidades de segurança)
CREATE POLICY "Permitir todas as operações em notas_sap" ON notas_sap
  FOR ALL USING (true) WITH CHECK (true);

-- Políticas para tasks_notas_sap: permitir todas as operações
CREATE POLICY "Permitir todas as operações em tasks_notas_sap" ON tasks_notas_sap
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
WHERE tablename IN ('notas_sap', 'tasks_notas_sap')
ORDER BY tablename, policyname;

