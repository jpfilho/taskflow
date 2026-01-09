-- Script de migração para adicionar segmento_id e segmento_nome à tabela comunidades
-- Execute este script se a tabela comunidades já existe sem essas colunas

-- 1. Adicionar colunas segmento_id e segmento_nome
ALTER TABLE comunidades 
  ADD COLUMN IF NOT EXISTS segmento_id UUID,
  ADD COLUMN IF NOT EXISTS segmento_nome VARCHAR(255);

-- 2. Remover a constraint UNIQUE antiga (se existir)
ALTER TABLE comunidades 
  DROP CONSTRAINT IF EXISTS comunidades_divisao_id_key;

-- 3. Adicionar nova constraint UNIQUE para (divisao_id, segmento_id)
-- Nota: Isso pode falhar se já houver dados duplicados
-- Se falhar, você precisará limpar os dados duplicados primeiro
DO $$
BEGIN
  -- Tentar adicionar a constraint
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'comunidades_divisao_id_segmento_id_key'
  ) THEN
    ALTER TABLE comunidades 
      ADD CONSTRAINT comunidades_divisao_id_segmento_id_key 
      UNIQUE(divisao_id, segmento_id);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Erro ao adicionar constraint. Pode haver dados duplicados. Erro: %', SQLERRM;
END $$;

-- 4. Criar índices para as novas colunas
CREATE INDEX IF NOT EXISTS idx_comunidades_segmento_id ON comunidades(segmento_id);
CREATE INDEX IF NOT EXISTS idx_comunidades_divisao_segmento ON comunidades(divisao_id, segmento_id);

-- 5. Se houver comunidades existentes sem segmento_id, você precisará atualizá-las manualmente
-- ou deletá-las para recriar com os dados corretos
-- Exemplo de atualização (descomente e ajuste conforme necessário):
-- UPDATE comunidades 
-- SET segmento_id = 'SEU_SEGMENTO_ID_AQUI', 
--     segmento_nome = 'SEU_SEGMENTO_NOME_AQUI'
-- WHERE segmento_id IS NULL;

-- 6. Tornar segmento_id e segmento_nome NOT NULL após preencher os dados
-- (Descomente após preencher todos os registros)
-- ALTER TABLE comunidades 
--   ALTER COLUMN segmento_id SET NOT NULL,
--   ALTER COLUMN segmento_nome SET NOT NULL;

-- Verificar estrutura da tabela
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'comunidades'
ORDER BY ordinal_position;

