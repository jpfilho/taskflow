-- ============================================
-- SQL PARA CRIAR A TABELA EMPRESAS NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: As tabelas 'regionais' e 'divisoes' devem ser criadas ANTES desta

-- Tabela de empresas
CREATE TABLE IF NOT EXISTS empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa VARCHAR(200) NOT NULL,
  regional_id UUID NOT NULL REFERENCES regionais(id) ON DELETE CASCADE,
  divisao_id UUID NOT NULL REFERENCES divisoes(id) ON DELETE CASCADE,
  tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('PROPRIA', 'TERCEIRA')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_empresas_empresa ON empresas(empresa);
CREATE INDEX IF NOT EXISTS idx_empresas_regional_id ON empresas(regional_id);
CREATE INDEX IF NOT EXISTS idx_empresas_divisao_id ON empresas(divisao_id);
CREATE INDEX IF NOT EXISTS idx_empresas_tipo ON empresas(tipo);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_empresas_updated_at ON empresas;
CREATE TRIGGER update_empresas_updated_at BEFORE UPDATE ON empresas
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE empresas ENABLE ROW LEVEL SECURITY;

-- Remover política existente se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em empresas" ON empresas;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em empresas" ON empresas
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE empresas IS 'Tabela de cadastro de empresas';
COMMENT ON COLUMN empresas.empresa IS 'Nome da empresa';
COMMENT ON COLUMN empresas.regional_id IS 'ID da regional associada';
COMMENT ON COLUMN empresas.divisao_id IS 'ID da divisão associada';
COMMENT ON COLUMN empresas.tipo IS 'Tipo da empresa: PROPRIA ou TERCEIRA';

-- Verificar se a tabela foi criada corretamente
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'empresas'
ORDER BY ordinal_position;

