-- ============================================
-- SQL PARA MIGRAR TABELA TASKS PARA USAR FOREIGN KEYS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: As tabelas regionais, divisoes, status e locais devem existir antes

-- Passo 1: Adicionar colunas de foreign keys (se não existirem)
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS status_id UUID REFERENCES status(id) ON DELETE SET NULL;

ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS regional_id UUID REFERENCES regionais(id) ON DELETE SET NULL;

ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS divisao_id UUID REFERENCES divisoes(id) ON DELETE SET NULL;

ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS local_id UUID REFERENCES locais(id) ON DELETE SET NULL;

-- Passo 2: Criar índices
CREATE INDEX IF NOT EXISTS idx_tasks_status_id ON tasks(status_id);
CREATE INDEX IF NOT EXISTS idx_tasks_regional_id ON tasks(regional_id);
CREATE INDEX IF NOT EXISTS idx_tasks_divisao_id ON tasks(divisao_id);
CREATE INDEX IF NOT EXISTS idx_tasks_local_id ON tasks(local_id);

-- Passo 3: Migrar dados existentes (se houver)
-- Você precisará associar manualmente os dados existentes
-- Exemplo para status:
-- UPDATE tasks t
-- SET status_id = s.id
-- FROM status s
-- WHERE t.status = s.codigo;
--
-- Exemplo para regional:
-- UPDATE tasks t
-- SET regional_id = r.id
-- FROM regionais r
-- WHERE t.regional = r.regional;
--
-- E assim por diante para divisao e local

-- Passo 4: Tornar as colunas obrigatórias (após migração)
-- Descomente estas linhas APENAS após migrar todos os dados:
-- ALTER TABLE tasks ALTER COLUMN status_id SET NOT NULL;
-- ALTER TABLE tasks ALTER COLUMN regional_id SET NOT NULL;
-- ALTER TABLE tasks ALTER COLUMN divisao_id SET NOT NULL;
-- ALTER TABLE tasks ALTER COLUMN local_id SET NOT NULL;

-- Passo 5: Remover colunas antigas (após migração completa)
-- Descomente estas linhas APENAS após garantir que todos os dados foram migrados:
-- ALTER TABLE tasks DROP COLUMN IF EXISTS status;
-- ALTER TABLE tasks DROP COLUMN IF EXISTS regional;
-- ALTER TABLE tasks DROP COLUMN IF EXISTS divisao;
-- ALTER TABLE tasks DROP COLUMN IF EXISTS local;

-- Comentários nas colunas
COMMENT ON COLUMN tasks.status_id IS 'ID do status associado';
COMMENT ON COLUMN tasks.regional_id IS 'ID da regional associada';
COMMENT ON COLUMN tasks.divisao_id IS 'ID da divisão associada';
COMMENT ON COLUMN tasks.local_id IS 'ID do local associado';

-- Verificar estrutura atual
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'tasks'
ORDER BY ordinal_position;

