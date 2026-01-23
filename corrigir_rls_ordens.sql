-- ============================================
-- SQL PARA CORRIGIR POLÍTICAS RLS DA TABELA ORDENS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Remover todas as políticas existentes
DROP POLICY IF EXISTS "Usuários autenticados podem ler ordens" ON ordens;
DROP POLICY IF EXISTS "Usuários autenticados podem inserir ordens" ON ordens;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar ordens" ON ordens;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar ordens" ON ordens;

-- Políticas para ordens: permitir todas as operações
-- (Ajuste conforme suas necessidades de segurança)
CREATE POLICY "Permitir todas as operações em ordens" ON ordens
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
WHERE tablename = 'ordens'
ORDER BY policyname;
