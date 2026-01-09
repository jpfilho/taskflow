-- Adicionar novos campos à tabela mensagens para suportar:
-- - Resposta a mensagens
-- - Marcação de usuários (@mention)
-- - Localização

-- Verificar se as colunas já existem antes de adicionar
DO $$ 
BEGIN
  -- Adicionar coluna mensagem_respondida_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'mensagens' AND column_name = 'mensagem_respondida_id'
  ) THEN
    ALTER TABLE mensagens 
    ADD COLUMN mensagem_respondida_id UUID REFERENCES mensagens(id) ON DELETE SET NULL;
  END IF;

  -- Adicionar coluna usuarios_mencionados
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'mensagens' AND column_name = 'usuarios_mencionados'
  ) THEN
    ALTER TABLE mensagens 
    ADD COLUMN usuarios_mencionados TEXT[] DEFAULT '{}';
  END IF;

  -- Adicionar coluna localizacao (JSONB para armazenar lat, lng, endereco)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'mensagens' AND column_name = 'localizacao'
  ) THEN
    ALTER TABLE mensagens 
    ADD COLUMN localizacao JSONB;
  END IF;
END $$;

-- Criar índice para melhorar performance nas consultas de mensagens respondidas
CREATE INDEX IF NOT EXISTS idx_mensagens_respondida_id 
ON mensagens(mensagem_respondida_id) 
WHERE mensagem_respondida_id IS NOT NULL;

-- Criar índice GIN para busca em usuarios_mencionados
CREATE INDEX IF NOT EXISTS idx_mensagens_usuarios_mencionados 
ON mensagens USING GIN(usuarios_mencionados) 
WHERE usuarios_mencionados IS NOT NULL AND array_length(usuarios_mencionados, 1) > 0;

-- Comentários nas colunas
COMMENT ON COLUMN mensagens.mensagem_respondida_id IS 'ID da mensagem que está sendo respondida';
COMMENT ON COLUMN mensagens.usuarios_mencionados IS 'Array de IDs dos usuários mencionados na mensagem (@mention)';
COMMENT ON COLUMN mensagens.localizacao IS 'Dados de localização em formato JSON: {lat, lng, endereco}';

