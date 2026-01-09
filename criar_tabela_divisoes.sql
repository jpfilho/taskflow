-- ============================================
-- SQL PARA CRIAR A TABELA DIVISOES NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Tabela de divisões
-- IMPORTANTE: A tabela segmentos deve ser criada ANTES desta
-- Uma regional pode ter várias divisões
-- Uma divisão pode ter vários segmentos (relacionamento many-to-many via divisoes_segmentos)
-- O nome da divisão deve ser único APENAS dentro da mesma regional
CREATE TABLE IF NOT EXISTS divisoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  divisao VARCHAR(100) NOT NULL,
  regional_id UUID NOT NULL REFERENCES regionais(id) ON DELETE CASCADE,
  -- NOTA: segmento_id foi removido. Use a tabela divisoes_segmentos para relacionamentos many-to-many
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- Constraint UNIQUE composta: divisão única por regional
  UNIQUE(divisao, regional_id)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_divisoes_divisao ON divisoes(divisao);
CREATE INDEX IF NOT EXISTS idx_divisoes_regional_id ON divisoes(regional_id);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_divisoes_updated_at ON divisoes;
CREATE TRIGGER update_divisoes_updated_at BEFORE UPDATE ON divisoes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE divisoes ENABLE ROW LEVEL SECURITY;

-- Remover política existente se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em divisoes" ON divisoes;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em divisoes" ON divisoes
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE divisoes IS 'Tabela de cadastro de divisões com regional. Segmentos são relacionados via tabela divisoes_segmentos (many-to-many)';
COMMENT ON COLUMN divisoes.divisao IS 'Nome da divisão';
COMMENT ON COLUMN divisoes.regional_id IS 'ID da regional associada';

-- Verificar se a tabela foi criada corretamente
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'divisoes'
ORDER BY ordinal_position;

