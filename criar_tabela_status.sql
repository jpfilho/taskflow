-- ============================================
-- SQL PARA CRIAR A TABELA STATUS NO SUPABASE
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Tabela de status
CREATE TABLE IF NOT EXISTS status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(4) NOT NULL UNIQUE,
  status VARCHAR(100) NOT NULL,
  cor VARCHAR(7) DEFAULT '#2196F3',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_status_codigo ON status(codigo);
CREATE INDEX IF NOT EXISTS idx_status_status ON status(status);

-- Função para atualizar updated_at automaticamente (se ainda não existir)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_status_updated_at ON status;
CREATE TRIGGER update_status_updated_at BEFORE UPDATE ON status
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Políticas RLS (Row Level Security)
ALTER TABLE status ENABLE ROW LEVEL SECURITY;

-- Remover política existente se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em status" ON status;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em status" ON status
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários na tabela
COMMENT ON TABLE status IS 'Tabela de cadastro de status com código e descrição';
COMMENT ON COLUMN status.codigo IS 'Código do status (4 caracteres, único)';
COMMENT ON COLUMN status.status IS 'Nome/descrição do status';
COMMENT ON COLUMN status.cor IS 'Cor do status em formato hexadecimal (ex: #FF5733)';

-- Verificar se a tabela foi criada corretamente
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable,
  character_maximum_length
FROM information_schema.columns
WHERE table_name = 'status'
ORDER BY ordinal_position;

