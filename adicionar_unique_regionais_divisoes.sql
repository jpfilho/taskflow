-- ============================================
-- ADICIONAR CONSTRAINTS UNIQUE PARA REGIONAIS E DIVISÕES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- Este script garante que os nomes de regionais e divisões sejam únicos

-- ============================================
-- 1. ADICIONAR UNIQUE PARA REGIONAIS
-- ============================================

-- Verificar se já existe constraint UNIQUE na coluna regional
DO $$
BEGIN
    -- Verificar se já existe uma constraint UNIQUE
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'regionais_regional_key' 
        AND conrelid = 'regionais'::regclass
    ) THEN
        -- Verificar se há duplicatas antes de adicionar a constraint
        IF EXISTS (
            SELECT regional, COUNT(*) 
            FROM regionais 
            GROUP BY regional 
            HAVING COUNT(*) > 1
        ) THEN
            RAISE NOTICE 'ATENÇÃO: Existem regionais duplicadas. Remova as duplicatas antes de adicionar a constraint UNIQUE.';
            RAISE NOTICE 'Execute: SELECT regional, COUNT(*) FROM regionais GROUP BY regional HAVING COUNT(*) > 1;';
        ELSE
            -- Adicionar constraint UNIQUE
            ALTER TABLE regionais 
            ADD CONSTRAINT regionais_regional_key UNIQUE (regional);
            RAISE NOTICE 'Constraint UNIQUE adicionada à coluna regional na tabela regionais.';
        END IF;
    ELSE
        RAISE NOTICE 'Constraint UNIQUE já existe na coluna regional da tabela regionais.';
    END IF;
END
$$;

-- ============================================
-- 2. ADICIONAR UNIQUE PARA DIVISÕES
-- ============================================

-- Verificar se já existe constraint UNIQUE na coluna divisao
DO $$
BEGIN
    -- Verificar se já existe uma constraint UNIQUE
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'divisoes_divisao_key' 
        AND conrelid = 'divisoes'::regclass
    ) THEN
        -- Verificar se há duplicatas antes de adicionar a constraint
        IF EXISTS (
            SELECT divisao, COUNT(*) 
            FROM divisoes 
            GROUP BY divisao 
            HAVING COUNT(*) > 1
        ) THEN
            RAISE NOTICE 'ATENÇÃO: Existem divisões duplicadas. Remova as duplicatas antes de adicionar a constraint UNIQUE.';
            RAISE NOTICE 'Execute: SELECT divisao, COUNT(*) FROM divisoes GROUP BY divisao HAVING COUNT(*) > 1;';
        ELSE
            -- Adicionar constraint UNIQUE
            ALTER TABLE divisoes 
            ADD CONSTRAINT divisoes_divisao_key UNIQUE (divisao);
            RAISE NOTICE 'Constraint UNIQUE adicionada à coluna divisao na tabela divisoes.';
        END IF;
    ELSE
        RAISE NOTICE 'Constraint UNIQUE já existe na coluna divisao da tabela divisoes.';
    END IF;
END
$$;

-- ============================================
-- 3. VERIFICAR DUPLICATAS (se houver)
-- ============================================

-- Listar regionais duplicadas (se houver)
SELECT 
    'Regionais duplicadas:' as tipo,
    regional, 
    COUNT(*) as quantidade,
    array_agg(id::text) as ids
FROM regionais 
GROUP BY regional 
HAVING COUNT(*) > 1;

-- Listar divisões duplicadas (se houver)
SELECT 
    'Divisões duplicadas:' as tipo,
    divisao, 
    COUNT(*) as quantidade,
    array_agg(id::text) as ids
FROM divisoes 
GROUP BY divisao 
HAVING COUNT(*) > 1;

-- ============================================
-- 4. VERIFICAR SE AS CONSTRAINTS FORAM CRIADAS
-- ============================================

SELECT 
    'regionais' as tabela,
    conname as constraint_name,
    contype as tipo
FROM pg_constraint 
WHERE conrelid = 'regionais'::regclass 
AND conname = 'regionais_regional_key'

UNION ALL

SELECT 
    'divisoes' as tabela,
    conname as constraint_name,
    contype as tipo
FROM pg_constraint 
WHERE conrelid = 'divisoes'::regclass 
AND conname = 'divisoes_divisao_key';

