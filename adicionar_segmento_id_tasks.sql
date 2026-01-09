-- ============================================
-- SQL PARA ADICIONAR SEGMENTO_ID NA TABELA TASKS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: A tabela segmentos deve existir antes

-- Passo 1: Adicionar coluna de foreign key
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS segmento_id UUID REFERENCES segmentos(id) ON DELETE SET NULL;

-- Passo 2: Criar índice
CREATE INDEX IF NOT EXISTS idx_tasks_segmento_id ON tasks(segmento_id);

-- Passo 3: (Opcional) Migrar dados existentes se houver uma coluna 'segmento' antiga
-- Se você tiver uma coluna 'segmento' (texto) na tabela tasks, pode migrar assim:
-- UPDATE tasks t
-- SET segmento_id = s.id
-- FROM segmentos s
-- WHERE t.segmento = s.segmento
-- AND t.segmento_id IS NULL;

-- Comentário na coluna
COMMENT ON COLUMN tasks.segmento_id IS 'ID do segmento associado';

-- Verificar estrutura atual
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'tasks'
AND column_name LIKE '%segmento%'
ORDER BY ordinal_position;

