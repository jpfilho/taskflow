-- ============================================
-- SQL PARA CRIAR A TABELA TIPOS_ATIVIDADE NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: A tabela 'segmentos' deve ser criada ANTES desta

-- Tabela de tipos de atividade
CREATE TABLE IF NOT EXISTS tipos_atividade (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(50) NOT NULL UNIQUE,
  descricao VARCHAR(255) NOT NULL,
  ativo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de junção para relacionamento many-to-many com segmentos
CREATE TABLE IF NOT EXISTS tipos_atividade_segmentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_atividade_id UUID NOT NULL REFERENCES tipos_atividade(id) ON DELETE CASCADE,
  segmento_id UUID NOT NULL REFERENCES segmentos(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tipo_atividade_id, segmento_id) -- Evitar duplicatas
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_tipos_atividade_codigo ON tipos_atividade(codigo);
CREATE INDEX IF NOT EXISTS idx_tipos_atividade_ativo ON tipos_atividade(ativo);
CREATE INDEX IF NOT EXISTS idx_tipos_atividade_segmentos_tipo_id ON tipos_atividade_segmentos(tipo_atividade_id);
CREATE INDEX IF NOT EXISTS idx_tipos_atividade_segmentos_segmento_id ON tipos_atividade_segmentos(segmento_id);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_tipos_atividade_updated_at ON tipos_atividade;
CREATE TRIGGER update_tipos_atividade_updated_at BEFORE UPDATE ON tipos_atividade
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE tipos_atividade ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_atividade_segmentos ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em tipos_atividade" ON tipos_atividade;
DROP POLICY IF EXISTS "Permitir todas as operações em tipos_atividade_segmentos" ON tipos_atividade_segmentos;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em tipos_atividade" ON tipos_atividade
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em tipos_atividade_segmentos" ON tipos_atividade_segmentos
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE tipos_atividade IS 'Tabela de cadastro de tipos de atividade';
COMMENT ON COLUMN tipos_atividade.codigo IS 'Código único do tipo de atividade';
COMMENT ON COLUMN tipos_atividade.descricao IS 'Descrição do tipo de atividade';
COMMENT ON COLUMN tipos_atividade.ativo IS 'Indica se o tipo de atividade está ativo';
COMMENT ON TABLE tipos_atividade_segmentos IS 'Tabela de junção para relacionamento many-to-many entre tipos de atividade e segmentos';

-- Verificar se as tabelas foram criadas corretamente
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name IN ('tipos_atividade', 'tipos_atividade_segmentos')
ORDER BY table_name, ordinal_position;

