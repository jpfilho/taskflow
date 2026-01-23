-- ============================================
-- SQL PARA CRIAR TABELA DE VINCULAÇÃO ENTRE TAREFAS E ATs
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Tabela de junção para vincular ATs às tarefas
CREATE TABLE IF NOT EXISTS tasks_ats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  at_id UUID NOT NULL REFERENCES ats(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_id, at_id) -- Evitar duplicatas
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_tasks_ats_task_id ON tasks_ats(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_ats_at_id ON tasks_ats(at_id);

-- RLS Policies
ALTER TABLE tasks_ats ENABLE ROW LEVEL SECURITY;

-- Política: Permitir todas as operações (ajuste conforme necessário)
CREATE POLICY "Permitir todas as operações em tasks_ats" ON tasks_ats
  FOR ALL USING (true) WITH CHECK (true);

-- Comentários
COMMENT ON TABLE tasks_ats IS 'Vínculos entre tarefas e ATs';
COMMENT ON COLUMN tasks_ats.task_id IS 'ID da tarefa';
COMMENT ON COLUMN tasks_ats.at_id IS 'ID da AT';
