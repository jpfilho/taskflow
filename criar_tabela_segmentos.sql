-- ============================================
-- SQL PARA CRIAR A TABELA SEGMENTOS NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Tabela de segmentos
CREATE TABLE IF NOT EXISTS segmentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  segmento VARCHAR(200) NOT NULL,
  descricao TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_segmentos_segmento ON segmentos(segmento);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_segmentos_updated_at ON segmentos;
CREATE TRIGGER update_segmentos_updated_at BEFORE UPDATE ON segmentos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE segmentos ENABLE ROW LEVEL SECURITY;

-- Remover política existente se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em segmentos" ON segmentos;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em segmentos" ON segmentos
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE segmentos IS 'Tabela de cadastro de segmentos';
COMMENT ON COLUMN segmentos.segmento IS 'Nome do segmento';
COMMENT ON COLUMN segmentos.descricao IS 'Descrição do segmento';

-- Verificar se a tabela foi criada corretamente
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'segmentos'
ORDER BY ordinal_position;

