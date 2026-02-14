-- ============================================
-- Permitir status RPGR (Reprogramado) na tabela tasks
-- ============================================
-- O app já envia RPGR ao salvar "Reprogramado"; o banco deve aceitar para
-- que a coluna status seja atualizada e o W5 não apareça para tarefas reprogramadas.
-- ============================================

DO $$
DECLARE
  conname TEXT;
BEGIN
  -- Remover constraints de check que restrinjam status (para incluir RPGR)
  FOR conname IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'tasks'
      AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) LIKE '%status%'
  LOOP
    EXECUTE format('ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS %I', conname);
  END LOOP;

  -- Adicionar constraint com RPGR (se ainda não existir tasks_status_check)
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    WHERE c.conrelid = 'public.tasks'::regclass AND c.conname = 'tasks_status_check'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_status_check
      CHECK (UPPER(TRIM(COALESCE(status, ''))) IN ('ANDA', 'CONC', 'PROG', 'CANC', 'RPAR', 'RPGR'));
  END IF;
END $$;

COMMENT ON CONSTRAINT tasks_status_check ON public.tasks IS
'Status permitidos: ANDA, CONC, PROG, CANC, RPAR, RPGR (Reprogramado).';
