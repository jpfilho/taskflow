-- ============================================
-- SQL PARA TESTAR INSERÇÃO DE ORDENS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Teste 1: Verificar se a tabela existe
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'ordens'
) AS tabela_existe;

-- Teste 2: Verificar políticas RLS
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'ordens';

-- Teste 3: Tentar inserir uma ordem de teste
INSERT INTO ordens (
  ordem,
  tipo,
  status_sistema,
  texto_breve,
  local_instalacao
) VALUES (
  'TESTE-001',
  'PREV',
  'TESTE',
  'Ordem de teste',
  'Local de teste'
) RETURNING id, ordem, created_at;

-- Teste 4: Verificar se a ordem foi inserida
SELECT * FROM ordens WHERE ordem = 'TESTE-001';

-- Teste 5: Deletar a ordem de teste
DELETE FROM ordens WHERE ordem = 'TESTE-001';
