-- ============================================
-- SQL PARA MIGRAR TABELA DIVISOES_SEGMENTOS PARA CHAVE PRIMÁRIA COMPOSTA
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: Este script corrige a estrutura da tabela divisoes_segmentos
-- se ela foi criada com uma coluna 'id' separada ao invés de chave primária composta

-- ============================================
-- PASSO 1: Verificar se a tabela tem coluna 'id'
-- ============================================
-- Execute esta query primeiro para verificar a estrutura atual:
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos'
ORDER BY ordinal_position;

-- ============================================
-- PASSO 2: Se a tabela tem coluna 'id', fazer backup dos dados
-- ============================================
-- Criar tabela temporária com backup
CREATE TABLE IF NOT EXISTS divisoes_segmentos_backup AS
SELECT * FROM divisoes_segmentos;

-- ============================================
-- PASSO 3: Remover constraints antigas
-- ============================================
-- Remover chave primária antiga (se existir)
ALTER TABLE divisoes_segmentos 
    DROP CONSTRAINT IF EXISTS divisoes_segmentos_pkey;

-- Remover constraint UNIQUE antiga (se existir)
ALTER TABLE divisoes_segmentos 
    DROP CONSTRAINT IF EXISTS divisoes_segmentos_divisao_id_segmento_id_key;

-- Remover coluna 'id' se existir
ALTER TABLE divisoes_segmentos 
    DROP COLUMN IF EXISTS id;

-- ============================================
-- PASSO 4: Criar nova chave primária composta
-- ============================================
ALTER TABLE divisoes_segmentos 
    ADD PRIMARY KEY (divisao_id, segmento_id);

-- ============================================
-- PASSO 5: Garantir que não há duplicatas
-- ============================================
-- Remover duplicatas (manter apenas a primeira ocorrência)
DELETE FROM divisoes_segmentos ds1
WHERE EXISTS (
    SELECT 1 FROM divisoes_segmentos ds2
    WHERE ds2.divisao_id = ds1.divisao_id
      AND ds2.segmento_id = ds1.segmento_id
      AND ds2.ctid < ds1.ctid
);

-- ============================================
-- PASSO 6: Recriar índices
-- ============================================
DROP INDEX IF EXISTS idx_divisoes_segmentos_divisao_id;
DROP INDEX IF EXISTS idx_divisoes_segmentos_segmento_id;

CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_divisao_id ON divisoes_segmentos(divisao_id);
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_segmento_id ON divisoes_segmentos(segmento_id);

-- ============================================
-- PASSO 7: Corrigir políticas RLS
-- ============================================
-- Remover todas as políticas antigas
DROP POLICY IF EXISTS "Permitir leitura de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir inserção de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir atualização de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir exclusão de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos;

-- Criar política única (compatível com outras tabelas)
CREATE POLICY "Permitir todas as operações em divisoes_segmentos" 
    ON divisoes_segmentos
    FOR ALL 
    USING (true) 
    WITH CHECK (true);

-- ============================================
-- PASSO 8: Verificar estrutura final
-- ============================================
SELECT 
    'Estrutura final' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos'
ORDER BY ordinal_position;

-- Verificar chave primária
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'divisoes_segmentos'
    AND tc.constraint_type = 'PRIMARY KEY'
ORDER BY kcu.ordinal_position;

-- Verificar dados
SELECT 
    COUNT(*) as total_relacionamentos,
    COUNT(DISTINCT divisao_id) as total_divisoes,
    COUNT(DISTINCT segmento_id) as total_segmentos
FROM divisoes_segmentos;

-- ============================================
-- PASSO 9: Limpar backup (após verificar que tudo está OK)
-- ============================================
-- Descomente esta linha APENAS após verificar que tudo está funcionando:
-- DROP TABLE IF EXISTS divisoes_segmentos_backup;







