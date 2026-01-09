-- Criar tabela de anexos
CREATE TABLE IF NOT EXISTS anexos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  nome_arquivo VARCHAR(255) NOT NULL,
  tipo_arquivo VARCHAR(20) NOT NULL CHECK (tipo_arquivo IN ('imagem', 'video', 'documento')),
  caminho_arquivo TEXT NOT NULL,
  tamanho_bytes INTEGER NOT NULL,
  mime_type VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índice para busca rápida por tarefa
CREATE INDEX IF NOT EXISTS idx_anexos_task_id ON anexos(task_id);

-- Criar índice para busca por tipo de arquivo
CREATE INDEX IF NOT EXISTS idx_anexos_tipo_arquivo ON anexos(tipo_arquivo);

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_anexos_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at
CREATE TRIGGER trigger_update_anexos_updated_at
  BEFORE UPDATE ON anexos
  FOR EACH ROW
  EXECUTE FUNCTION update_anexos_updated_at();

-- Habilitar RLS (Row Level Security)
ALTER TABLE anexos ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Permitir todas as operações em anexos" ON anexos;

-- Política para permitir todas as operações
CREATE POLICY "Permitir todas as operações em anexos" ON anexos
  FOR ALL USING (true) WITH CHECK (true);

