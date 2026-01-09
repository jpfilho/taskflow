-- ============================================
-- SQL PARA CRIAR TABELA DE CURTIDAS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Tabela de curtidas (likes) de tarefas
CREATE TABLE IF NOT EXISTS task_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_id, usuario_id) -- Garante que cada usuário só pode curtir uma vez por tarefa
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_task_likes_task_id ON task_likes(task_id);
CREATE INDEX IF NOT EXISTS idx_task_likes_usuario_id ON task_likes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_task_likes_created_at ON task_likes(created_at DESC);

-- Políticas RLS (Row Level Security)
ALTER TABLE task_likes ENABLE ROW LEVEL SECURITY;

-- Política: Todos podem ver curtidas (ajustar se necessário restringir)
CREATE POLICY "Todos podem ver curtidas"
  ON task_likes
  FOR SELECT
  USING (true);

-- Política: Permitir inserção de curtidas
-- A validação de duplicatas é feita pela constraint UNIQUE(task_id, usuario_id)
CREATE POLICY "Permitir criar curtidas"
  ON task_likes
  FOR INSERT
  WITH CHECK (true);

-- Política: Permitir deletar curtidas
-- A validação de permissão pode ser feita no código da aplicação
CREATE POLICY "Permitir deletar curtidas"
  ON task_likes
  FOR DELETE
  USING (true);
