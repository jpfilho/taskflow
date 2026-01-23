-- Criar tabela de junção 'tasks_sis' para vincular tarefas a SIs
CREATE TABLE IF NOT EXISTS tasks_sis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  si_id UUID NOT NULL REFERENCES sis(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(task_id, si_id)
);

-- Criar índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_tasks_sis_task_id ON tasks_sis(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_sis_si_id ON tasks_sis(si_id);

-- Comentários
COMMENT ON TABLE tasks_sis IS 'Tabela de junção entre tarefas e SIs';
COMMENT ON COLUMN tasks_sis.task_id IS 'ID da tarefa';
COMMENT ON COLUMN tasks_sis.si_id IS 'ID da SI';

-- Habilitar RLS (Row Level Security)
ALTER TABLE tasks_sis ENABLE ROW LEVEL SECURITY;

-- Política RLS: usuários podem ver todas as vinculações
CREATE POLICY "tasks_sis_select_policy" ON tasks_sis
  FOR SELECT
  USING (true);

-- Política RLS: usuários autenticados podem inserir vinculações
CREATE POLICY "tasks_sis_insert_policy" ON tasks_sis
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Política RLS: usuários autenticados podem deletar vinculações
CREATE POLICY "tasks_sis_delete_policy" ON tasks_sis
  FOR DELETE
  USING (auth.role() = 'authenticated');
