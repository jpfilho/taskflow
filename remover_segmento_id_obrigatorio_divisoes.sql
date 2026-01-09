-- ============================================
-- REMOVER SEGMENTO_ID OBRIGATÓRIO DA TABELA DIVISOES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- 
-- PROBLEMA: A tabela divisoes tem segmento_id NOT NULL, mas estamos usando
-- a tabela divisoes_segmentos para o relacionamento many-to-many.
-- A coluna segmento_id não é mais necessária ou deve ser opcional.

-- ============================================
-- OPÇÃO 1: Tornar segmento_id opcional (nullable)
-- ============================================
-- Use esta opção se você quiser manter a coluna para compatibilidade

DO $$
BEGIN
    -- Verificar se a coluna existe
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'divisoes' 
        AND column_name = 'segmento_id'
    ) THEN
        -- Tornar a coluna opcional (nullable)
        ALTER TABLE divisoes 
        ALTER COLUMN segmento_id DROP NOT NULL;
        
        RAISE NOTICE 'Coluna segmento_id tornada opcional (nullable) na tabela divisoes.';
    ELSE
        RAISE NOTICE 'Coluna segmento_id não existe na tabela divisoes.';
    END IF;
END
$$;

-- ============================================
-- OPÇÃO 2: Remover a coluna segmento_id completamente
-- ============================================
-- Use esta opção se você não precisa mais da coluna
-- Descomente as linhas abaixo se quiser remover:

-- DO $$
-- BEGIN
--     -- Remover índice primeiro
--     DROP INDEX IF EXISTS idx_divisoes_segmento_id;
--     
--     -- Remover a coluna
--     ALTER TABLE divisoes DROP COLUMN IF EXISTS segmento_id;
--     
--     RAISE NOTICE 'Coluna segmento_id removida da tabela divisoes.';
-- END
-- $$;

-- ============================================
-- VERIFICAR ESTRUTURA ATUAL
-- ============================================

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'divisoes'
ORDER BY ordinal_position;






