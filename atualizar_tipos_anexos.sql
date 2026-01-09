-- Atualizar constraint da tabela anexos para incluir novos tipos
-- Execute este script no SQL Editor do Supabase

-- Remover constraint antiga
ALTER TABLE anexos DROP CONSTRAINT IF EXISTS anexos_tipo_arquivo_check;

-- Adicionar nova constraint com todos os tipos
ALTER TABLE anexos ADD CONSTRAINT anexos_tipo_arquivo_check 
  CHECK (tipo_arquivo IN ('imagem', 'video', 'documento', 'audio', 'outro'));

-- Verificar se a constraint foi aplicada
SELECT 
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'anexos'::regclass
  AND conname = 'anexos_tipo_arquivo_check';

