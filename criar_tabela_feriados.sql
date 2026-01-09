-- Criar tabela de feriados
CREATE TABLE IF NOT EXISTS feriados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  data DATE NOT NULL,
  descricao VARCHAR(255) NOT NULL,
  tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('NACIONAL', 'ESTADUAL', 'MUNICIPAL')),
  pais VARCHAR(100),
  estado VARCHAR(100),
  cidade VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Remover constraint se já existir e criar novamente
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'feriados_tipo_check'
  ) THEN
    ALTER TABLE feriados DROP CONSTRAINT feriados_tipo_check;
  END IF;
END $$;

-- Adicionar constraint de validação do tipo
ALTER TABLE feriados ADD CONSTRAINT feriados_tipo_check CHECK (
  (tipo = 'NACIONAL' AND pais IS NOT NULL AND estado IS NULL AND cidade IS NULL) OR
  (tipo = 'ESTADUAL' AND pais IS NOT NULL AND estado IS NOT NULL AND cidade IS NULL) OR
  (tipo = 'MUNICIPAL' AND pais IS NOT NULL AND estado IS NOT NULL AND cidade IS NOT NULL)
);

-- Criar índice para busca rápida por data
CREATE INDEX IF NOT EXISTS idx_feriados_data ON feriados(data);

-- Criar índice para busca por tipo
CREATE INDEX IF NOT EXISTS idx_feriados_tipo ON feriados(tipo);

-- Criar índice composto para busca por localização
CREATE INDEX IF NOT EXISTS idx_feriados_localizacao ON feriados(pais, estado, cidade);

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_feriados_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at
CREATE TRIGGER trigger_update_feriados_updated_at
  BEFORE UPDATE ON feriados
  FOR EACH ROW
  EXECUTE FUNCTION update_feriados_updated_at();

-- Habilitar RLS (Row Level Security)
ALTER TABLE feriados ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Permitir leitura de feriados para usuários autenticados" ON feriados;
DROP POLICY IF EXISTS "Permitir inserção de feriados para usuários autenticados" ON feriados;
DROP POLICY IF EXISTS "Permitir atualização de feriados para usuários autenticados" ON feriados;
DROP POLICY IF EXISTS "Permitir exclusão de feriados para usuários autenticados" ON feriados;

-- Política para permitir leitura para todos os usuários autenticados
CREATE POLICY "Permitir leitura de feriados para usuários autenticados"
  ON feriados
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Política para permitir inserção para usuários autenticados
CREATE POLICY "Permitir inserção de feriados para usuários autenticados"
  ON feriados
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Política para permitir atualização para usuários autenticados
CREATE POLICY "Permitir atualização de feriados para usuários autenticados"
  ON feriados
  FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- Política para permitir exclusão para usuários autenticados
CREATE POLICY "Permitir exclusão de feriados para usuários autenticados"
  ON feriados
  FOR DELETE
  USING (auth.role() = 'authenticated');

