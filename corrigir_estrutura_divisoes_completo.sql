-- ============================================
-- CORRIGIR ESTRUTURA COMPLETA DA TABELA DIVISOES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- 
-- Este script corrige a estrutura para suportar:
-- - Uma regional pode ter várias divisões
-- - Uma divisão pode ter vários segmentos (via tabela divisoes_segmentos)

-- ============================================
-- PASSO 1: Tornar segmento_id opcional (se existir)
-- ============================================

DO $$
BEGIN
    -- Verificar se a coluna existe e é NOT NULL
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'divisoes' 
        AND column_name = 'segmento_id'
        AND is_nullable = 'NO'
    ) THEN
        -- Tornar a coluna opcional (nullable)
        ALTER TABLE divisoes 
        ALTER COLUMN segmento_id DROP NOT NULL;
        
        RAISE NOTICE '✅ Coluna segmento_id tornada opcional (nullable) na tabela divisoes.';
    ELSIF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'divisoes' 
        AND column_name = 'segmento_id'
    ) THEN
        RAISE NOTICE 'ℹ️ Coluna segmento_id já é opcional.';
    ELSE
        RAISE NOTICE '✅ Coluna segmento_id não existe (isso é CORRETO - usamos a tabela divisoes_segmentos para relacionamentos many-to-many).';
    END IF;
END
$$;

-- ============================================
-- PASSO 2: Remover constraint UNIQUE global de divisao (se existir)
-- ============================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'divisoes_divisao_key' 
        AND conrelid = 'divisoes'::regclass
    ) THEN
        ALTER TABLE divisoes 
        DROP CONSTRAINT divisoes_divisao_key;
        RAISE NOTICE '✅ Constraint UNIQUE global removida da coluna divisao.';
    ELSE
        RAISE NOTICE 'ℹ️ Constraint UNIQUE global não existe na coluna divisao.';
    END IF;
END
$$;

-- ============================================
-- PASSO 3: Adicionar constraint UNIQUE composta (divisao, regional_id)
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'divisoes_divisao_regional_id_key' 
        AND conrelid = 'divisoes'::regclass
    ) THEN
        -- Verificar se há duplicatas antes de adicionar
        IF EXISTS (
            SELECT divisao, regional_id, COUNT(*) 
            FROM divisoes 
            GROUP BY divisao, regional_id 
            HAVING COUNT(*) > 1
        ) THEN
            RAISE NOTICE '⚠️ ATENÇÃO: Existem divisões duplicadas na mesma regional.';
            RAISE NOTICE 'Execute: SELECT divisao, regional_id, COUNT(*) FROM divisoes GROUP BY divisao, regional_id HAVING COUNT(*) > 1;';
        ELSE
            ALTER TABLE divisoes 
            ADD CONSTRAINT divisoes_divisao_regional_id_key UNIQUE (divisao, regional_id);
            RAISE NOTICE '✅ Constraint UNIQUE composta (divisao, regional_id) adicionada.';
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️ Constraint UNIQUE composta (divisao, regional_id) já existe.';
    END IF;
END
$$;

-- ============================================
-- PASSO 4: Garantir que a tabela divisoes_segmentos existe
-- ============================================

CREATE TABLE IF NOT EXISTS divisoes_segmentos (
    divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE CASCADE,
    segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (divisao_id, segmento_id)
);

-- Criar índices se não existirem
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_divisao_id ON divisoes_segmentos(divisao_id);
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_segmento_id ON divisoes_segmentos(segmento_id);

-- Habilitar RLS
ALTER TABLE divisoes_segmentos ENABLE ROW LEVEL SECURITY;

-- Política RLS
DROP POLICY IF EXISTS "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos;
CREATE POLICY "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos
  FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- PASSO 5: Verificar estrutura final
-- ============================================

-- Estrutura da tabela divisoes
SELECT 
    'divisoes' as tabela,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes'
ORDER BY ordinal_position;

-- Constraints da tabela divisoes
SELECT 
    'divisoes' as tabela,
    conname as constraint_name,
    contype as tipo,
    pg_get_constraintdef(oid) as definicao
FROM pg_constraint 
WHERE conrelid = 'divisoes'::regclass
ORDER BY conname;

-- Estrutura da tabela divisoes_segmentos
SELECT 
    'divisoes_segmentos' as tabela,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos'
ORDER BY ordinal_position;

