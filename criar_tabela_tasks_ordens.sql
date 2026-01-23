-- ============================================
-- SQL PARA CRIAR TABELA DE VINCULAÇÃO ENTRE TAREFAS E ORDENS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Tabela de junção para vincular ordens às tarefas
CREATE TABLE IF NOT EXISTS tasks_ordens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  ordem_id UUID NOT NULL REFERENCES ordens(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_id, ordem_id) -- Evitar duplicatas
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_tasks_ordens_task_id ON tasks_ordens(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_ordens_ordem_id ON tasks_ordens(ordem_id);

-- RLS Policies
ALTER TABLE tasks_ordens ENABLE ROW LEVEL SECURITY;

-- Política: Permitir todas as operações (ajuste conforme necessário)
CREATE POLICY "Permitir todas as operações em tasks_ordens" ON tasks_ordens
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários
COMMENT ON TABLE tasks_ordens IS 'Vínculos entre tarefas e ordens';
COMMENT ON COLUMN tasks_ordens.task_id IS 'ID da tarefa';
COMMENT ON COLUMN tasks_ordens.ordem_id IS 'ID da ordem';
