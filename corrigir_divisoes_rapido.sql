-- ============================================
-- CORREÇÃO RÁPIDA PARA TABELA DIVISOES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- Este script corrige a estrutura para permitir criar divisões sem segmento_id

-- PASSO 1: Tornar segmento_id opcional (nullable) - apenas se a coluna existir
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'divisoes' 
        AND column_name = 'segmento_id'
    ) THEN
        ALTER TABLE divisoes 
        ALTER COLUMN segmento_id DROP NOT NULL;
        RAISE NOTICE '✅ Coluna segmento_id tornada opcional.';
    ELSE
        RAISE NOTICE 'ℹ️ Coluna segmento_id não existe (isso é correto - usamos divisoes_segmentos).';
    END IF;
END
$$;

-- PASSO 2: Remover constraint UNIQUE global de divisao (se existir)
ALTER TABLE divisoes 
DROP CONSTRAINT IF EXISTS divisoes_divisao_key;

-- PASSO 3: Adicionar constraint UNIQUE composta (divisao, regional_id)
-- Primeiro, verificar se a constraint já existe
DO $$
BEGIN
    -- Verificar se a constraint já existe
    IF EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'divisoes_divisao_regional_id_key' 
        AND conrelid = 'divisoes'::regclass
    ) THEN
        RAISE NOTICE 'ℹ️ Constraint divisoes_divisao_regional_id_key já existe.';
    ELSE
        -- Se não existir, verificar se há duplicatas antes de adicionar
        IF EXISTS (
            SELECT 1 
            FROM (
                SELECT divisao, regional_id, COUNT(*) 
                FROM divisoes 
                GROUP BY divisao, regional_id 
                HAVING COUNT(*) > 1
            ) duplicatas
        ) THEN
            RAISE NOTICE '⚠️ Existem duplicatas. Remova-as antes de adicionar a constraint.';
        ELSE
            ALTER TABLE divisoes 
            ADD CONSTRAINT divisoes_divisao_regional_id_key UNIQUE (divisao, regional_id);
            RAISE NOTICE '✅ Constraint UNIQUE composta adicionada.';
        END IF;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE 'ℹ️ Constraint já existe (capturado por exception).';
END
$$;

-- PASSO 4: Garantir que a tabela divisoes_segmentos existe
CREATE TABLE IF NOT EXISTS divisoes_segmentos (
    divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE CASCADE,
    segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (divisao_id, segmento_id)
);

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_divisao_id ON divisoes_segmentos(divisao_id);
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_segmento_id ON divisoes_segmentos(segmento_id);

-- Habilitar RLS
ALTER TABLE divisoes_segmentos ENABLE ROW LEVEL SECURITY;

-- Política RLS
DROP POLICY IF EXISTS "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos;
CREATE POLICY "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos
  FOR ALL USING (true) WITH CHECK (true);

-- VERIFICAR RESULTADO
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes'
ORDER BY ordinal_position;

