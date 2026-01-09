-- ============================================
-- SQL PARA CRIAR A TABELA LOCAIS NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: As tabelas regionais, divisoes e segmentos devem existir antes

-- Tabela de locais
CREATE TABLE IF NOT EXISTS locais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  local VARCHAR(200) NOT NULL,
  descricao TEXT,
  -- Flags para associação ampla
  para_toda_regional BOOLEAN DEFAULT FALSE,
  para_toda_divisao BOOLEAN DEFAULT FALSE,
  -- Associações específicas (nullable - pode ser NULL se for para toda regional/divisão)
  regional_id UUID REFERENCES regionais(id) ON DELETE CASCADE,
  divisao_id UUID REFERENCES divisoes(id) ON DELETE CASCADE,
  segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- Constraint: se não for para toda regional/divisão, deve ter pelo menos uma associação específica
  CONSTRAINT locais_associacao_check CHECK (
    para_toda_regional = TRUE OR 
    para_toda_divisao = TRUE OR 
    regional_id IS NOT NULL OR 
    divisao_id IS NOT NULL OR 
    segmento_id IS NOT NULL
  )
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_locais_local ON locais(local);
CREATE INDEX IF NOT EXISTS idx_locais_regional_id ON locais(regional_id);
CREATE INDEX IF NOT EXISTS idx_locais_divisao_id ON locais(divisao_id);
CREATE INDEX IF NOT EXISTS idx_locais_segmento_id ON locais(segmento_id);
CREATE INDEX IF NOT EXISTS idx_locais_para_toda_regional ON locais(para_toda_regional);
CREATE INDEX IF NOT EXISTS idx_locais_para_toda_divisao ON locais(para_toda_divisao);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_locais_updated_at ON locais;
CREATE TRIGGER update_locais_updated_at BEFORE UPDATE ON locais
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE locais ENABLE ROW LEVEL SECURITY;

-- Remover política existente se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em locais" ON locais;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em locais" ON locais
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE locais IS 'Tabela de cadastro de locais com associações flexíveis';
COMMENT ON COLUMN locais.local IS 'Nome do local';
COMMENT ON COLUMN locais.descricao IS 'Descrição do local';
COMMENT ON COLUMN locais.para_toda_regional IS 'Se TRUE, o local se aplica a toda a regional';
COMMENT ON COLUMN locais.para_toda_divisao IS 'Se TRUE, o local se aplica a toda a divisão';
COMMENT ON COLUMN locais.regional_id IS 'ID da regional específica (se não for para toda regional)';
COMMENT ON COLUMN locais.divisao_id IS 'ID da divisão específica (se não for para toda divisão)';
COMMENT ON COLUMN locais.segmento_id IS 'ID do segmento específico';

-- Verificar se a tabela foi criada corretamente
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'locais'
ORDER BY ordinal_position;

