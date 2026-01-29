-- ============================================
-- VINCULAR SEGMENTS (MÍDIA) COM SEGMENTOS (SISTEMA)
-- ============================================
-- Este script cria uma relação entre a tabela 'segments' (módulo de mídia)
-- e a tabela 'segmentos' (sistema TaskFlow) baseada no nome
-- ============================================

-- Opção 1: Adicionar coluna segmento_id na tabela segments para referenciar segmentos
-- (Recomendado se você quer manter a relação explícita)

ALTER TABLE segments 
ADD COLUMN IF NOT EXISTS segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL;

-- Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_segments_segmento_id ON segments(segmento_id);

-- Opção 2: Popular segmento_id baseado no nome (se os nomes correspondem)
-- Execute este UPDATE apenas se os nomes em 'segments.name' correspondem aos nomes em 'segmentos.segmento'
-- 
-- UPDATE segments s
-- SET segmento_id = seg.id
-- FROM segmentos seg
-- WHERE LOWER(TRIM(s.name)) = LOWER(TRIM(seg.segmento))
-- AND s.segmento_id IS NULL;

-- ============================================
-- NOTAS
-- ============================================
-- 1. Se você preferir usar a tabela 'segmentos' diretamente ao invés de 'segments',
--    você pode modificar o código para usar SegmentoService ao invés de criar uma nova tabela.
--
-- 2. Alternativamente, você pode manter 'segments' separado e fazer o filtro por nome
--    (como implementado no código Dart)
--
-- 3. Se os segmentos são os mesmos, considere usar a tabela 'segmentos' diretamente
--    e remover a tabela 'segments', ajustando o código para usar SegmentoService
-- ============================================
