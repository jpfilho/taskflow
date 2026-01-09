-- ============================================
-- SQL PARA CRIAR TABELAS DE JUNÇÃO PARA TASKS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
--
-- IMPORTANTE: As tabelas 'tasks', 'locais', 'executores' e 'equipes' devem existir ANTES desta

-- Tabela de junção para relacionamento N:N entre tasks e locais
CREATE TABLE IF NOT EXISTS tasks_locais (
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  local_id UUID REFERENCES locais(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, local_id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de junção para relacionamento N:N entre tasks e executores
CREATE TABLE IF NOT EXISTS tasks_executores (
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  executor_id UUID REFERENCES executores(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, executor_id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de junção para relacionamento N:N entre tasks e equipes
CREATE TABLE IF NOT EXISTS tasks_equipes (
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  equipe_id UUID REFERENCES equipes(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, equipe_id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_tasks_locais_task_id ON tasks_locais(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_locais_local_id ON tasks_locais(local_id);
CREATE INDEX IF NOT EXISTS idx_tasks_executores_task_id ON tasks_executores(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_executores_executor_id ON tasks_executores(executor_id);
CREATE INDEX IF NOT EXISTS idx_tasks_equipes_task_id ON tasks_equipes(task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_equipes_equipe_id ON tasks_equipes(equipe_id);

-- Políticas RLS (Row Level Security)
ALTER TABLE tasks_locais ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks_executores ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks_equipes ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes se houver (para evitar duplicatas)
DROP POLICY IF EXISTS "Permitir todas as operações em tasks_locais" ON tasks_locais;
DROP POLICY IF EXISTS "Permitir todas as operações em tasks_executores" ON tasks_executores;
DROP POLICY IF EXISTS "Permitir todas as operações em tasks_equipes" ON tasks_equipes;

-- Políticas para permitir todas as operações
CREATE POLICY "Permitir todas as operações em tasks_locais" ON tasks_locais
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em tasks_executores" ON tasks_executores
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Permitir todas as operações em tasks_equipes" ON tasks_equipes
  FOR ALL USING (true) WITH CHECK (true);

-- Migrar dados existentes das colunas diretas para as tabelas de junção
DO $$
BEGIN
    -- Migrar local_id para tasks_locais
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'local_id') THEN
        RAISE NOTICE 'Migrando dados de local_id da tabela tasks para tasks_locais...';
        INSERT INTO tasks_locais (task_id, local_id)
        SELECT id, local_id
        FROM tasks
        WHERE local_id IS NOT NULL
        ON CONFLICT (task_id, local_id) DO NOTHING;
        RAISE NOTICE 'Migração de locais concluída.';
    END IF;

    -- Migrar equipe_id para tasks_equipes
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'equipe_id') THEN
        RAISE NOTICE 'Migrando dados de equipe_id da tabela tasks para tasks_equipes...';
        INSERT INTO tasks_equipes (task_id, equipe_id)
        SELECT id, equipe_id
        FROM tasks
        WHERE equipe_id IS NOT NULL
        ON CONFLICT (task_id, equipe_id) DO NOTHING;
        RAISE NOTICE 'Migração de equipes concluída.';
    END IF;

    -- Para executores, não há coluna direta, então não há migração necessária
    RAISE NOTICE 'Migração concluída.';
END $$;

-- Comentários nas tabelas
COMMENT ON TABLE tasks_locais IS 'Tabela de junção para associar múltiplos locais a uma tarefa';
COMMENT ON TABLE tasks_executores IS 'Tabela de junção para associar múltiplos executores a uma tarefa';
COMMENT ON TABLE tasks_equipes IS 'Tabela de junção para associar múltiplas equipes a uma tarefa';

-- Verificar se as tabelas foram criadas corretamente
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name IN ('tasks_locais', 'tasks_executores', 'tasks_equipes')
ORDER BY table_name, ordinal_position;

