-- ============================================
-- SQL PARA CRIAR A TABELA FUNCOES NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Tabela de funções
CREATE TABLE IF NOT EXISTS funcoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  funcao VARCHAR(200) NOT NULL,
  descricao TEXT,
  ativo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_funcoes_funcao ON funcoes(funcao);
CREATE INDEX IF NOT EXISTS idx_funcoes_ativo ON funcoes(ativo);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_funcoes_updated_at ON funcoes;
CREATE TRIGGER update_funcoes_updated_at BEFORE UPDATE ON funcoes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE funcoes ENABLE ROW LEVEL SECURITY;

-- Remover política existente se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em funcoes" ON funcoes;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em funcoes" ON funcoes
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE funcoes IS 'Tabela de cadastro de funções/cargos';
COMMENT ON COLUMN funcoes.funcao IS 'Nome da função/cargo';
COMMENT ON COLUMN funcoes.descricao IS 'Descrição da função';
COMMENT ON COLUMN funcoes.ativo IS 'Indica se a função está ativa';

-- Verificar se a tabela foi criada corretamente
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'funcoes'
ORDER BY ordinal_position;

