-- ============================================
-- SQL PARA ADICIONAR VÍNCULOS DE REGIONAL, DIVISÃO E SEGMENTO À TABELA EQUIPES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
--
-- IMPORTANTE: Execute este script se a tabela 'equipes' já foi criada sem essas colunas

DO $$
BEGIN
    -- Adicionar coluna regional_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'equipes' AND column_name = 'regional_id') THEN
        ALTER TABLE equipes ADD COLUMN regional_id UUID REFERENCES regionais(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_equipes_regional_id ON equipes(regional_id);
        RAISE NOTICE 'Coluna regional_id adicionada à tabela equipes.';
    ELSE
        RAISE NOTICE 'Coluna regional_id já existe na tabela equipes.';
    END IF;

    -- Adicionar coluna divisao_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'equipes' AND column_name = 'divisao_id') THEN
        ALTER TABLE equipes ADD COLUMN divisao_id UUID REFERENCES divisoes(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_equipes_divisao_id ON equipes(divisao_id);
        RAISE NOTICE 'Coluna divisao_id adicionada à tabela equipes.';
    ELSE
        RAISE NOTICE 'Coluna divisao_id já existe na tabela equipes.';
    END IF;

    -- Adicionar coluna segmento_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'equipes' AND column_name = 'segmento_id') THEN
        ALTER TABLE equipes ADD COLUMN segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_equipes_segmento_id ON equipes(segmento_id);
        RAISE NOTICE 'Coluna segmento_id adicionada à tabela equipes.';
    ELSE
        RAISE NOTICE 'Coluna segmento_id já existe na tabela equipes.';
    END IF;

    -- Comentários nas novas colunas
    COMMENT ON COLUMN equipes.regional_id IS 'ID da regional associada (opcional)';
    COMMENT ON COLUMN equipes.divisao_id IS 'ID da divisão associada (opcional)';
    COMMENT ON COLUMN equipes.segmento_id IS 'ID do segmento associado (opcional)';
    RAISE NOTICE 'Comentários nas colunas atualizados.';

    -- Verificar se as colunas foram adicionadas corretamente
    RAISE NOTICE 'Verificando estrutura final da tabela equipes:';
    PERFORM
      column_name,
      data_type,
      is_nullable
    FROM information_schema.columns
    WHERE table_name = 'equipes'
    ORDER BY ordinal_position;

END $$;







