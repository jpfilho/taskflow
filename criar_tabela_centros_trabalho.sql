-- ============================================
-- SQL PARA CRIAR TABELA DE CENTROS DE TRABALHO
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Tabela de Centros de Trabalho
CREATE TABLE IF NOT EXISTS centros_trabalho (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  centro_trabalho TEXT NOT NULL,
  descricao TEXT,
  regional_id UUID NOT NULL REFERENCES regionais(id) ON DELETE RESTRICT,
  divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE RESTRICT,
  segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE RESTRICT,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_centros_trabalho_regional_id ON centros_trabalho(regional_id);
CREATE INDEX IF NOT EXISTS idx_centros_trabalho_divisao_id ON centros_trabalho(divisao_id);
CREATE INDEX IF NOT EXISTS idx_centros_trabalho_segmento_id ON centros_trabalho(segmento_id);
CREATE INDEX IF NOT EXISTS idx_centros_trabalho_centro_trabalho ON centros_trabalho(centro_trabalho);
CREATE INDEX IF NOT EXISTS idx_centros_trabalho_ativo ON centros_trabalho(ativo);

-- RLS Policies
ALTER TABLE centros_trabalho ENABLE ROW LEVEL SECURITY;

-- Política: Permitir todas as operações (ajuste conforme necessário)
CREATE POLICY "Permitir todas as operações em centros_trabalho" ON centros_trabalho
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários
COMMENT ON TABLE centros_trabalho IS 'Centros de Trabalho vinculados a Regional, Divisão e Segmento';
COMMENT ON COLUMN centros_trabalho.centro_trabalho IS 'Nome do centro de trabalho';
COMMENT ON COLUMN centros_trabalho.regional_id IS 'ID da regional (obrigatório)';
COMMENT ON COLUMN centros_trabalho.divisao_id IS 'ID da divisão (obrigatório)';
COMMENT ON COLUMN centros_trabalho.segmento_id IS 'ID do segmento (obrigatório)';
COMMENT ON COLUMN centros_trabalho.ativo IS 'Indica se o centro de trabalho está ativo';
