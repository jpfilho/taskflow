-- ============================================
-- SQL PARA CRIAR A TABELA REGIONAIS NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Tabela de regionais
CREATE TABLE IF NOT EXISTS regionais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  regional VARCHAR(100) NOT NULL UNIQUE,
  divisao VARCHAR(100) NOT NULL,
  empresa VARCHAR(200) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_regionais_regional ON regionais(regional);
CREATE INDEX IF NOT EXISTS idx_regionais_divisao ON regionais(divisao);
CREATE INDEX IF NOT EXISTS idx_regionais_empresa ON regionais(empresa);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_regionais_updated_at ON regionais;
CREATE TRIGGER update_regionais_updated_at BEFORE UPDATE ON regionais
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE regionais ENABLE ROW LEVEL SECURITY;

-- Remover política existente se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em regionais" ON regionais;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em regionais" ON regionais
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE regionais IS 'Tabela de cadastro de regionais com divisão e empresa';
COMMENT ON COLUMN regionais.regional IS 'Nome da regional';
COMMENT ON COLUMN regionais.divisao IS 'Nome da divisão';
COMMENT ON COLUMN regionais.empresa IS 'Nome da empresa';

-- Verificar se a tabela foi criada corretamente
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'regionais'
ORDER BY ordinal_position;

