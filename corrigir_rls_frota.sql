-- ============================================
-- SQL PARA CORRIGIR POLÍTICAS RLS DA TABELA FROTA
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Remover todas as políticas existentes
DROP POLICY IF EXISTS "Usuários autenticados podem ver frota" ON frota;
DROP POLICY IF EXISTS "Usuários autenticados podem criar frota" ON frota;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar frota" ON frota;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar frota" ON frota;

-- Criar políticas que funcionam com autenticação customizada
-- Política: Todos os usuários autenticados podem ver todas as frotas
CREATE POLICY "Usuários autenticados podem ver frota"
  ON frota
  FOR SELECT
  USING (true);

-- Política: Usuários autenticados podem criar frota
CREATE POLICY "Usuários autenticados podem criar frota"
  ON frota
  FOR INSERT
  WITH CHECK (true);

-- Política: Usuários autenticados podem atualizar frota
CREATE POLICY "Usuários autenticados podem atualizar frota"
  ON frota
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Política: Usuários autenticados podem deletar frota
CREATE POLICY "Usuários autenticados podem deletar frota"
  ON frota
  FOR DELETE
  USING (true);

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
WHERE tablename = 'frota'
ORDER BY policyname;
