-- ============================================
-- SQL COMPLETO PARA MIGRAR TABELA DIVISOES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: 
-- 1. Execute PRIMEIRO: criar_tabela_segmentos.sql
-- 2. Depois execute este script

-- Passo 1: Adicionar coluna segmento_id (se não existir)
ALTER TABLE divisoes 
ADD COLUMN IF NOT EXISTS segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL;

-- Passo 2: Criar índice
CREATE INDEX IF NOT EXISTS idx_divisoes_segmento_id ON divisoes(segmento_id);

-- Passo 3: Migrar dados existentes (se houver)
-- Se você já tem dados na tabela divisoes com valores em 'segmento' (texto),
-- você precisará criar os segmentos correspondentes na tabela segmentos primeiro
-- e depois associar manualmente usando um UPDATE como este:
--
-- UPDATE divisoes d
-- SET segmento_id = s.id
-- FROM segmentos s
-- WHERE d.segmento = s.segmento;
--
-- Ou criar segmentos automaticamente a partir dos valores únicos:
-- INSERT INTO segmentos (segmento)
-- SELECT DISTINCT segmento FROM divisoes
-- WHERE segmento IS NOT NULL AND segmento != ''
-- ON CONFLICT DO NOTHING;
--
-- Depois associar:
-- UPDATE divisoes d
-- SET segmento_id = s.id
-- FROM segmentos s
-- WHERE d.segmento = s.segmento;

-- Passo 4: Tornar segmento_id obrigatório (após migração)
-- Descomente estas linhas APENAS após migrar todos os dados:
-- ALTER TABLE divisoes ALTER COLUMN segmento_id SET NOT NULL;

-- Passo 5: Remover coluna antiga segmento (após migração completa)
-- Descomente esta linha APENAS após garantir que todos os dados foram migrados:
-- ALTER TABLE divisoes DROP COLUMN IF EXISTS segmento;

-- Comentário na coluna
COMMENT ON COLUMN divisoes.segmento_id IS 'ID do segmento associado';

-- Verificar estrutura atual
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes'
ORDER BY ordinal_position;

