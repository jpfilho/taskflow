-- ============================================
-- SQL PARA ATUALIZAR TABELA DIVISOES PARA USAR SEGMENTO_ID
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: 
-- 1. Execute este script APÓS criar a tabela segmentos
-- 2. Se você já tem dados na tabela divisoes, você precisará:
--    a) Criar os segmentos correspondentes na tabela segmentos primeiro
--    b) Associar manualmente os segmentos às divisões
--    c) Depois executar este script

-- Adicionar coluna segmento_id
ALTER TABLE divisoes 
ADD COLUMN IF NOT EXISTS segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL;

-- Índice para melhor performance
CREATE INDEX IF NOT EXISTS idx_divisoes_segmento_id ON divisoes(segmento_id);

-- Comentário na coluna
COMMENT ON COLUMN divisoes.segmento_id IS 'ID do segmento associado';

-- IMPORTANTE: Após migrar todos os dados e garantir que segmento_id está preenchido,
-- você pode tornar a coluna NOT NULL e remover a coluna antiga:
-- 
-- ALTER TABLE divisoes ALTER COLUMN segmento_id SET NOT NULL;
-- ALTER TABLE divisoes DROP COLUMN IF EXISTS segmento;

