-- ============================================
-- SQL PARA CRIAR TABELA DE JUNÇÃO EXECUTORES_SEGMENTOS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: As tabelas 'executores' e 'segmentos' devem existir ANTES desta

-- Criar tabela de junção para relacionamento many-to-many
CREATE TABLE IF NOT EXISTS executores_segmentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  executor_id UUID NOT NULL REFERENCES executores(id) ON DELETE CASCADE,
  segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(executor_id, segmento_id) -- Evitar duplicatas
);

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_executores_segmentos_executor_id ON executores_segmentos(executor_id);
CREATE INDEX IF NOT EXISTS idx_executores_segmentos_segmento_id ON executores_segmentos(segmento_id);

-- Habilitar RLS (Row Level Security)
ALTER TABLE executores_segmentos ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas as operações
DROP POLICY IF EXISTS "Permitir todas as operações em executores_segmentos" ON executores_segmentos;
CREATE POLICY "Permitir todas as operações em executores_segmentos" ON executores_segmentos
  FOR ALL USING (true) WITH CHECK (true);

-- Migrar dados existentes de segmento_id para a tabela de junção
-- (se houver executores com segmento_id preenchido)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'executores' AND column_name = 'segmento_id'
  ) THEN
    INSERT INTO executores_segmentos (executor_id, segmento_id)
    SELECT id, segmento_id
    FROM executores
    WHERE segmento_id IS NOT NULL
    ON CONFLICT (executor_id, segmento_id) DO NOTHING;
    
    RAISE NOTICE 'Dados migrados de executores.segmento_id para executores_segmentos';
  END IF;
END $$;

-- Comentários na tabela
COMMENT ON TABLE executores_segmentos IS 'Tabela de junção para relacionamento many-to-many entre executores e segmentos';
COMMENT ON COLUMN executores_segmentos.executor_id IS 'ID do executor';
COMMENT ON COLUMN executores_segmentos.segmento_id IS 'ID do segmento';

-- Verificar se a tabela foi criada corretamente
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'executores_segmentos'
ORDER BY ordinal_position;

