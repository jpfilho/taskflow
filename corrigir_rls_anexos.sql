-- Script para corrigir as políticas RLS da tabela anexos
-- Execute este script se encontrar erros de RLS ao criar/editar anexos

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Permitir todas as operações em anexos" ON anexos;

-- Criar política única que permite todas as operações
CREATE POLICY "Permitir todas as operações em anexos" ON anexos
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
WHERE tablename = 'anexos';

