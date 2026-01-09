-- ============================================
-- SQL PARA REMOVER COLUNA SEGMENTO_ID DA TABELA DIVISOES
-- ============================================
-- Execute este script APENAS após migrar todos os dados para a tabela divisoes_segmentos
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: Execute o script de migração primeiro (criar_tabela_divisoes_segmentos.sql)
-- e migre todos os dados antes de executar este script

-- Remover índice da coluna antiga
DROP INDEX IF EXISTS idx_divisoes_segmento_id;

-- Remover a coluna segmento_id (após migração completa)
ALTER TABLE divisoes DROP COLUMN IF EXISTS segmento_id;

-- Verificar estrutura atual
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes'
ORDER BY ordinal_position;

