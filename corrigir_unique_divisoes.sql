-- ============================================
-- CORRIGIR CONSTRAINT UNIQUE PARA DIVISÕES
-- ============================================
-- Uma regional pode ter várias divisões
-- Uma divisão pode ter vários segmentos
-- O nome da divisão deve ser único APENAS dentro da mesma regional
-- Execute este script no SQL Editor do Supabase Dashboard

-- ============================================
-- 1. REMOVER CONSTRAINT UNIQUE GLOBAL DA COLUNA divisao
-- ============================================

DO $$
BEGIN
    -- Remover constraint UNIQUE global se existir
    IF EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'divisoes_divisao_key' 
        AND conrelid = 'divisoes'::regclass
    ) THEN
        ALTER TABLE divisoes 
        DROP CONSTRAINT divisoes_divisao_key;
        RAISE NOTICE 'Constraint UNIQUE global removida da coluna divisao.';
    ELSE
        RAISE NOTICE 'Constraint UNIQUE global não existe na coluna divisao.';
    END IF;
END
$$;

-- ============================================
-- 2. ADICIONAR CONSTRAINT UNIQUE COMPOSTA (divisao, regional_id)
-- ============================================

DO $$
BEGIN
    -- Verificar se já existe constraint UNIQUE composta
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'divisoes_divisao_regional_id_key' 
        AND conrelid = 'divisoes'::regclass
    ) THEN
        -- Verificar se há duplicatas antes de adicionar a constraint
        IF EXISTS (
            SELECT divisao, regional_id, COUNT(*) 
            FROM divisoes 
            GROUP BY divisao, regional_id 
            HAVING COUNT(*) > 1
        ) THEN
            RAISE NOTICE 'ATENÇÃO: Existem divisões duplicadas na mesma regional. Remova as duplicatas antes de adicionar a constraint UNIQUE.';
            RAISE NOTICE 'Execute: SELECT divisao, regional_id, COUNT(*) FROM divisoes GROUP BY divisao, regional_id HAVING COUNT(*) > 1;';
        ELSE
            -- Adicionar constraint UNIQUE composta
            ALTER TABLE divisoes 
            ADD CONSTRAINT divisoes_divisao_regional_id_key UNIQUE (divisao, regional_id);
            RAISE NOTICE 'Constraint UNIQUE composta (divisao, regional_id) adicionada à tabela divisoes.';
        END IF;
    ELSE
        RAISE NOTICE 'Constraint UNIQUE composta (divisao, regional_id) já existe na tabela divisoes.';
    END IF;
END
$$;

-- ============================================
-- 3. VERIFICAR DUPLICATAS (se houver)
-- ============================================

-- Listar divisões duplicadas na mesma regional (se houver)
SELECT 
    'Divisões duplicadas na mesma regional:' as tipo,
    divisao, 
    regional_id,
    COUNT(*) as quantidade,
    array_agg(id::text) as ids
FROM divisoes 
GROUP BY divisao, regional_id 
HAVING COUNT(*) > 1;

-- ============================================
-- 4. VERIFICAR SE A CONSTRAINT FOI CRIADA
-- ============================================

SELECT 
    'divisoes' as tabela,
    conname as constraint_name,
    contype as tipo,
    pg_get_constraintdef(oid) as definicao
FROM pg_constraint 
WHERE conrelid = 'divisoes'::regclass 
AND conname = 'divisoes_divisao_regional_id_key';






