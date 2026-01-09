-- ============================================
-- SQL PARA CORRIGIR ESTRUTURA DIVISÕES-SEGMENTOS NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: Execute este script para garantir que a estrutura está correta
-- para o relacionamento many-to-many entre divisões e segmentos

-- ============================================
-- PASSO 1: Criar tabela divisoes_segmentos (se não existir)
-- ============================================
CREATE TABLE IF NOT EXISTS divisoes_segmentos (
    divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE CASCADE,
    segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (divisao_id, segmento_id), -- Chave primária composta
    UNIQUE(divisao_id, segmento_id) -- Garantir unicidade
);

-- ============================================
-- PASSO 2: Criar índices para melhor performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_divisao_id ON divisoes_segmentos(divisao_id);
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_segmento_id ON divisoes_segmentos(segmento_id);

-- ============================================
-- PASSO 3: Migrar dados existentes (se houver segmento_id na tabela divisoes)
-- ============================================
-- Verificar se a coluna segmento_id existe na tabela divisoes antes de migrar
DO $$
BEGIN
    -- Verificar se a coluna segmento_id existe
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'divisoes' 
        AND column_name = 'segmento_id'
    ) THEN
        -- Se existe, migrar os dados
        INSERT INTO divisoes_segmentos (divisao_id, segmento_id)
        SELECT id, segmento_id
        FROM divisoes
        WHERE segmento_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM divisoes_segmentos ds 
            WHERE ds.divisao_id = divisoes.id 
            AND ds.segmento_id = divisoes.segmento_id
          )
        ON CONFLICT (divisao_id, segmento_id) DO NOTHING;
        
        RAISE NOTICE 'Dados migrados da coluna segmento_id para divisoes_segmentos';
    ELSE
        RAISE NOTICE 'Coluna segmento_id não existe na tabela divisoes. Pulando migração.';
    END IF;
END $$;

-- ============================================
-- PASSO 4: Configurar RLS (Row Level Security)
-- ============================================
ALTER TABLE divisoes_segmentos ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas (se existirem)
DROP POLICY IF EXISTS "Permitir leitura de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir inserção de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir atualização de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir exclusão de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos;

-- Criar política única para permitir todas as operações (compatível com outras tabelas)
CREATE POLICY "Permitir todas as operações em divisoes_segmentos" 
    ON divisoes_segmentos
    FOR ALL 
    USING (true) 
    WITH CHECK (true);

-- ============================================
-- PASSO 5: Tornar segmento_id opcional na tabela divisoes (se ainda for NOT NULL)
-- ============================================
-- IMPORTANTE: Execute este passo APENAS após migrar todos os dados
-- e garantir que a tabela divisoes_segmentos está funcionando corretamente

-- Remover constraint NOT NULL se existir (apenas se a coluna existir)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'divisoes' 
        AND column_name = 'segmento_id'
    ) THEN
        -- Tentar remover NOT NULL (pode falhar se não for NOT NULL)
        BEGIN
            ALTER TABLE divisoes 
                ALTER COLUMN segmento_id DROP NOT NULL;
            RAISE NOTICE 'Constraint NOT NULL removida da coluna segmento_id';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Coluna segmento_id já é opcional ou não tem constraint NOT NULL: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'Coluna segmento_id não existe na tabela divisoes. Pulando alteração.';
    END IF;
END $$;

-- ============================================
-- PASSO 6: Adicionar comentários
-- ============================================
COMMENT ON TABLE divisoes_segmentos IS 'Tabela de relacionamento many-to-many entre divisões e segmentos';
COMMENT ON COLUMN divisoes_segmentos.divisao_id IS 'ID da divisão';
COMMENT ON COLUMN divisoes_segmentos.segmento_id IS 'ID do segmento';
COMMENT ON COLUMN divisoes_segmentos.created_at IS 'Data de criação do relacionamento';

-- ============================================
-- PASSO 7: Verificar estrutura criada
-- ============================================
SELECT 
    'divisoes_segmentos' as tabela,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos'
ORDER BY ordinal_position;

-- Verificar relacionamentos
SELECT 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'divisoes_segmentos';

-- Verificar dados migrados
SELECT 
    COUNT(*) as total_relacionamentos,
    COUNT(DISTINCT divisao_id) as total_divisoes,
    COUNT(DISTINCT segmento_id) as total_segmentos
FROM divisoes_segmentos;

