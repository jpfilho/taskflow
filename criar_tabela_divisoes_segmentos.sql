-- ============================================
-- SQL PARA CRIAR TABELA DE RELACIONAMENTO DIVISÕES-SEGMENTOS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: As tabelas divisoes e segmentos devem existir antes

-- Criar tabela de relacionamento many-to-many
-- IMPORTANTE: Usando chave primária composta (divisao_id, segmento_id) ao invés de id separado
CREATE TABLE IF NOT EXISTS divisoes_segmentos (
    divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE CASCADE,
    segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (divisao_id, segmento_id), -- Chave primária composta
    UNIQUE(divisao_id, segmento_id) -- Garantir unicidade
);

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_divisao_id ON divisoes_segmentos(divisao_id);
CREATE INDEX IF NOT EXISTS idx_divisoes_segmentos_segmento_id ON divisoes_segmentos(segmento_id);

-- Habilitar RLS (Row Level Security)
ALTER TABLE divisoes_segmentos ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas (se existirem)
DROP POLICY IF EXISTS "Permitir leitura de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir inserção de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir atualização de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir exclusão de divisoes_segmentos para usuários autenticados" ON divisoes_segmentos;
DROP POLICY IF EXISTS "Permitir todas as operações em divisoes_segmentos" ON divisoes_segmentos;

-- Política única para permitir todas as operações (compatível com outras tabelas)
CREATE POLICY "Permitir todas as operações em divisoes_segmentos" 
    ON divisoes_segmentos
    FOR ALL 
    USING (true) 
    WITH CHECK (true);

-- Comentários nas colunas
COMMENT ON TABLE divisoes_segmentos IS 'Tabela de relacionamento many-to-many entre divisões e segmentos';
COMMENT ON COLUMN divisoes_segmentos.divisao_id IS 'ID da divisão';
COMMENT ON COLUMN divisoes_segmentos.segmento_id IS 'ID do segmento';

-- Script para migrar dados existentes (se houver segmento_id na tabela divisoes)
-- Execute este script APENAS se você já tiver dados na tabela divisoes com segmento_id
-- e quiser migrar para a nova estrutura:
/*
INSERT INTO divisoes_segmentos (divisao_id, segmento_id)
SELECT id, segmento_id
FROM divisoes
WHERE segmento_id IS NOT NULL
ON CONFLICT (divisao_id, segmento_id) DO NOTHING;
*/

-- Verificar estrutura
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes_segmentos'
ORDER BY ordinal_position;

