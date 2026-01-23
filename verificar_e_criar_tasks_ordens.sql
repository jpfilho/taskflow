-- ============================================
-- SQL PARA VERIFICAR E CRIAR TABELA tasks_ordens
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- 1. Verificar se a tabela existe
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'tasks_ordens'
    ) 
    THEN '✅ Tabela tasks_ordens existe'
    ELSE '❌ Tabela tasks_ordens NÃO existe'
  END AS status;

-- 2. Se não existir, criar a tabela
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'tasks_ordens'
  ) THEN
    -- Criar a tabela
    CREATE TABLE tasks_ordens (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      ordem_id UUID NOT NULL REFERENCES ordens(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(task_id, ordem_id) -- Evitar duplicatas
    );

    -- Criar índices para melhor performance
    CREATE INDEX idx_tasks_ordens_task_id ON tasks_ordens(task_id);
    CREATE INDEX idx_tasks_ordens_ordem_id ON tasks_ordens(ordem_id);

    -- Habilitar RLS
    ALTER TABLE tasks_ordens ENABLE ROW LEVEL SECURITY;

    -- Criar política permissiva (ajuste conforme necessário)
    CREATE POLICY "Permitir todas as operações em tasks_ordens" ON tasks_ordens
      FOR ALL USING (true) WITH CHECK (true);

    -- Adicionar comentários
    COMMENT ON TABLE tasks_ordens IS 'Vínculos entre tarefas e ordens';
    COMMENT ON COLUMN tasks_ordens.task_id IS 'ID da tarefa';
    COMMENT ON COLUMN tasks_ordens.ordem_id IS 'ID da ordem';

    RAISE NOTICE '✅ Tabela tasks_ordens criada com sucesso!';
  ELSE
    RAISE NOTICE 'ℹ️ Tabela tasks_ordens já existe';
  END IF;
END $$;

-- 3. Verificar RLS Policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'tasks_ordens';

-- 4. Verificar estrutura da tabela
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'tasks_ordens'
ORDER BY ordinal_position;

-- 5. Contar registros existentes
SELECT COUNT(*) AS total_vinculos FROM tasks_ordens;
