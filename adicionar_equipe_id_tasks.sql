-- ============================================
-- SQL PARA ADICIONAR COLUNA EQUIPE_ID NA TABELA TASKS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
--
-- IMPORTANTE: A tabela 'equipes' deve ser criada ANTES desta

DO $$
BEGIN
    -- Adicionar coluna equipe_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'equipe_id') THEN
        ALTER TABLE tasks ADD COLUMN equipe_id UUID REFERENCES equipes(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_tasks_equipe_id ON tasks(equipe_id);
        RAISE NOTICE 'Coluna equipe_id adicionada à tabela tasks.';
    ELSE
        RAISE NOTICE 'Coluna equipe_id já existe na tabela tasks.';
    END IF;

    -- Comentário na nova coluna
    COMMENT ON COLUMN tasks.equipe_id IS 'ID da equipe associada (opcional). Se preenchido, a equipe substitui os executores individuais.';
    RAISE NOTICE 'Comentário na coluna atualizado.';

    -- Verificar se a coluna foi adicionada corretamente
    RAISE NOTICE 'Verificando estrutura da tabela tasks:';
    PERFORM
      column_name,
      data_type,
      is_nullable
    FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'equipe_id';

END $$;

