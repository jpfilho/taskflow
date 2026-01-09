-- ============================================
-- SQL PARA CRIAR A TABELA EQUIPES NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: A tabela 'executores' deve ser criada ANTES desta

-- Tabela de equipes
CREATE TABLE IF NOT EXISTS equipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome VARCHAR(255) NOT NULL,
  descricao TEXT,
  tipo VARCHAR(10) NOT NULL, -- 'FIXA' ou 'FLEXIVEL'
  regional_id UUID REFERENCES regionais(id) ON DELETE SET NULL,
  divisao_id UUID REFERENCES divisoes(id) ON DELETE SET NULL,
  segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL,
  ativo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT equipes_tipo_check CHECK (tipo IN ('FIXA', 'FLEXIVEL'))
);

-- Tabela de junção para relacionamento many-to-many com executores e seus papéis
CREATE TABLE IF NOT EXISTS equipes_executores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipe_id UUID NOT NULL REFERENCES equipes(id) ON DELETE CASCADE,
  executor_id UUID NOT NULL REFERENCES executores(id) ON DELETE CASCADE,
  papel VARCHAR(20) NOT NULL, -- 'FISCAL', 'TST', 'ENCARREGADO', 'EXECUTOR'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(equipe_id, executor_id), -- Evitar duplicatas
  CONSTRAINT equipes_executores_papel_check CHECK (papel IN ('FISCAL', 'TST', 'ENCARREGADO', 'EXECUTOR'))
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_equipes_nome ON equipes(nome);
CREATE INDEX IF NOT EXISTS idx_equipes_tipo ON equipes(tipo);
CREATE INDEX IF NOT EXISTS idx_equipes_ativo ON equipes(ativo);
CREATE INDEX IF NOT EXISTS idx_equipes_regional_id ON equipes(regional_id);
CREATE INDEX IF NOT EXISTS idx_equipes_divisao_id ON equipes(divisao_id);
CREATE INDEX IF NOT EXISTS idx_equipes_segmento_id ON equipes(segmento_id);
CREATE INDEX IF NOT EXISTS idx_equipes_executores_equipe_id ON equipes_executores(equipe_id);
CREATE INDEX IF NOT EXISTS idx_equipes_executores_executor_id ON equipes_executores(executor_id);
CREATE INDEX IF NOT EXISTS idx_equipes_executores_papel ON equipes_executores(papel);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_equipes_updated_at ON equipes;
CREATE TRIGGER update_equipes_updated_at BEFORE UPDATE ON equipes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE equipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipes_executores ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em equipes" ON equipes;
DROP POLICY IF EXISTS "Permitir todas as operações em equipes_executores" ON equipes_executores;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em equipes" ON equipes
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em equipes_executores" ON equipes_executores
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE equipes IS 'Tabela de cadastro de equipes';
COMMENT ON COLUMN equipes.nome IS 'Nome da equipe';
COMMENT ON COLUMN equipes.descricao IS 'Descrição da equipe';
COMMENT ON COLUMN equipes.tipo IS 'Tipo da equipe (FIXA ou FLEXIVEL)';
COMMENT ON COLUMN equipes.regional_id IS 'ID da regional associada (opcional)';
COMMENT ON COLUMN equipes.divisao_id IS 'ID da divisão associada (opcional)';
COMMENT ON COLUMN equipes.segmento_id IS 'ID do segmento associado (opcional)';
COMMENT ON COLUMN equipes.ativo IS 'Indica se a equipe está ativa';
COMMENT ON TABLE equipes_executores IS 'Tabela de junção para relacionamento many-to-many entre equipes e executores com papéis';
COMMENT ON COLUMN equipes_executores.papel IS 'Papel do executor na equipe (FISCAL, TST, ENCARREGADO, EXECUTOR)';

-- Verificar se as tabelas foram criadas corretamente
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name IN ('equipes', 'equipes_executores')
ORDER BY table_name, ordinal_position;

