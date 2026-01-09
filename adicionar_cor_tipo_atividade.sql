-- ============================================
-- SQL PARA ADICIONAR COLUNA COR NA TABELA TIPOS_ATIVIDADE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

DO $$
BEGIN
    -- Adicionar a coluna cor se ela não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tipos_atividade' AND column_name = 'cor') THEN
        ALTER TABLE tipos_atividade
        ADD COLUMN cor VARCHAR(7) NULL; -- Formato hexadecimal: #RRGGBB
        
        -- Adicionar comentário à coluna
        COMMENT ON COLUMN tipos_atividade.cor IS 'Cor hexadecimal (opcional) para exibição no Gantt. Formato: #RRGGBB';
        
        RAISE NOTICE 'Coluna cor adicionada na tabela tipos_atividade.';
    ELSE
        RAISE NOTICE 'Coluna cor já existe na tabela tipos_atividade.';
    END IF;
END
$$;

