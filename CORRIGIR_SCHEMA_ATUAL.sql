-- ============================================
-- SCRIPT PARA CORRIGIR O SCHEMA ATUAL DO BANCO
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- Este script corrige os problemas identificados no schema atual:
-- 1. Remove coluna 'segmento' da tabela divisoes
-- 2. Corrige tabela divisoes_segmentos para usar chave primária composta
-- 3. Garante que todas as foreign keys estão corretas

-- ============================================
-- PARTE 1: CORRIGIR TABELA DIVISOES_SEGMENTOS
-- ============================================
SELECT '=== CORRIGINDO DIVISOES_SEGMENTOS ===' as info;

-- Fazer backup dos dados existentes
CREATE TABLE IF NOT EXISTS divisoes_segmentos_backup AS
SELECT * FROM divisoes_segmentos;

-- Remover chave primária antiga (id)
ALTER TABLE divisoes_segmentos 
    DROP CONSTRAINT IF EXISTS divisoes_segmentos_pkey;

-- Remover coluna id se existir
ALTER TABLE divisoes_segmentos 
    DROP COLUMN IF EXISTS id;

-- Criar constraint UNIQUE se não existir (para evitar duplicatas)
ALTER TABLE divisoes_segmentos 
    DROP CONSTRAINT IF EXISTS divisoes_segmentos_divisao_id_segmento_id_key;

ALTER TABLE divisoes_segmentos 
    ADD CONSTRAINT divisoes_segmentos_divisao_id_segmento_id_key 
    UNIQUE (divisao_id, segmento_id);

-- Criar nova chave primária composta
ALTER TABLE divisoes_segmentos 
    ADD CONSTRAINT divisoes_segmentos_pkey 
    PRIMARY KEY (divisao_id, segmento_id);

-- Remover duplicatas (manter apenas a primeira ocorrência)
DELETE FROM divisoes_segmentos ds1
WHERE EXISTS (
    SELECT 1 FROM divisoes_segmentos ds2
    WHERE ds2.divisao_id = ds1.divisao_id
      AND ds2.segmento_id = ds1.segmento_id
      AND ds2.ctid < ds1.ctid
);

-- Recriar índices
DROP INDEX IF EXISTS idx_divisoes_segmentos_divisao_id;
DROP INDEX IF EXISTS idx_divisoes_segmentos_segmento_id;

CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_divisao_id ON divisoes_segmentos(divisao_id);
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_segmento_id ON divisoes_segmentos(segmento_id);

-- ============================================
-- PARTE 2: REMOVER COLUNA SEGMENTO DA TABELA DIVISOES
-- ============================================
SELECT '=== REMOVENDO COLUNA SEGMENTO DE DIVISOES ===' as info;

-- IMPORTANTE: Antes de remover, migrar dados se necessário
-- Se você tem dados na coluna 'segmento' (texto) e quer migrar para divisoes_segmentos:
-- Execute este bloco apenas se precisar migrar dados:

DO $$
DECLARE
    divisao_record RECORD;
    segmento_record RECORD;
BEGIN
    -- Para cada divisão que tem um valor em 'segmento'
    FOR divisao_record IN 
        SELECT id, segmento 
        FROM divisoes 
        WHERE segmento IS NOT NULL 
          AND segmento != ''
    LOOP
        -- Tentar encontrar o segmento correspondente
        SELECT id INTO segmento_record
        FROM segmentos
        WHERE segmento = divisao_record.segmento
        LIMIT 1;
        
        -- Se encontrou o segmento, criar relacionamento
        IF segmento_record.id IS NOT NULL THEN
            -- Inserir relacionamento se não existir
            INSERT INTO divisoes_segmentos (divisao_id, segmento_id)
            VALUES (divisao_record.id, segmento_record.id)
            ON CONFLICT (divisao_id, segmento_id) DO NOTHING;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Migração de dados concluída';
END $$;

-- Agora remover a coluna segmento
ALTER TABLE divisoes 
    DROP COLUMN IF EXISTS segmento;

-- Remover índice antigo se existir
DROP INDEX IF EXISTS idx_divisoes_segmento;

-- ============================================
-- PARTE 3: CORRIGIR POLÍTICAS RLS
-- ============================================
SELECT '=== CORRIGINDO POLÍTICAS RLS ===' as info;

-- Corrigir políticas de divisoes_segmentos
ALTER TABLE divisoes_segmentos ENABLE ROW LEVEL SECURITY;

-- Remover todas as políticas antigas
DROP POLICY IF EXISTS "Permitir leitura de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir inserção de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir atualização de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir exclusão de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos;

-- Criar política correta
CREATE POLICY "Permitir todas as operações em divisoes_segmentos" 
    ON divisoes_segmentos
    FOR ALL 
    USING (true) 
    WITH CHECK (true);

-- ============================================
-- PARTE 4: VERIFICAÇÃO FINAL
-- ============================================
SELECT '=== VERIFICAÇÃO FINAL ===' as info;

-- Verificar estrutura de divisoes
SELECT 
    'Estrutura divisoes' as tipo,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes'
ORDER BY ordinal_position;

-- Verificar estrutura de divisoes_segmentos
SELECT 
    'Estrutura divisoes_segmentos' as tipo,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos'
ORDER BY ordinal_position;

-- Verificar chave primária de divisoes_segmentos
SELECT
    'Chave primária divisoes_segmentos' as tipo,
    tc.constraint_name,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'divisoes_segmentos'
    AND tc.constraint_type = 'PRIMARY KEY'
ORDER BY kcu.ordinal_position;

-- Verificar dados migrados
SELECT 
    'Dados em divisoes_segmentos' as tipo,
    COUNT(*) as total_relacionamentos,
    COUNT(DISTINCT divisao_id) as total_divisoes,
    COUNT(DISTINCT segmento_id) as total_segmentos
FROM divisoes_segmentos;

-- Verificar se coluna segmento foi removida
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'divisoes' AND column_name = 'segmento'
        ) THEN '❌ Coluna segmento ainda existe'
        ELSE '✅ Coluna segmento foi removida'
    END as status_coluna_segmento;

SELECT '=== SCRIPT CONCLUÍDO ===' as info;

-- ============================================
-- LIMPEZA (Execute após verificar que tudo está OK)
-- ============================================
-- Descomente esta linha APENAS após verificar que tudo está funcionando:
-- DROP TABLE IF EXISTS divisoes_segmentos_backup;

