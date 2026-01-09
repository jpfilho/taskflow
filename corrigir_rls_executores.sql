-- ============================================
-- SQL PARA CORRIGIR POLÍTICAS RLS DA TABELA EXECUTORES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Remover todas as políticas existentes
DROP POLICY IF EXISTS "Permitir leitura de executores para usuários autenticados" ON executores;
DROP POLICY IF EXISTS "Permitir inserção de executores para usuários autenticados" ON executores;
DROP POLICY IF EXISTS "Permitir atualização de executores para usuários autenticados" ON executores;
DROP POLICY IF EXISTS "Permitir exclusão de executores para usuários autenticados" ON executores;
DROP POLICY IF EXISTS "Permitir todas as operações em executores" ON executores;

-- Criar política única que permite todas as operações
CREATE POLICY "Permitir todas as operações em executores" ON executores
  FOR ALL USING (true) WITH CHECK (true);

-- Verificar se a política foi criada
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
WHERE tablename = 'executores';

