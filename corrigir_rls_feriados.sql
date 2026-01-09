-- Script para corrigir as políticas RLS da tabela feriados
-- Execute este script se encontrar erros de RLS ao criar/editar feriados

-- Remover todas as políticas existentes
DROP POLICY IF EXISTS "Permitir leitura de feriados para usuários autenticados" ON feriados;
DROP POLICY IF EXISTS "Permitir inserção de feriados para usuários autenticados" ON feriados;
DROP POLICY IF EXISTS "Permitir atualização de feriados para usuários autenticados" ON feriados;
DROP POLICY IF EXISTS "Permitir exclusão de feriados para usuários autenticados" ON feriados;
DROP POLICY IF EXISTS "Permitir todas as operações em feriados" ON feriados;

-- Criar política única que permite todas as operações (mais simples e confiável)
CREATE POLICY "Permitir todas as operações em feriados" ON feriados
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
WHERE tablename = 'feriados';

