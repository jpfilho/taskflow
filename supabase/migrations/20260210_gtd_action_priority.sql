-- Prioridade da ação: alta, média, baixa.
ALTER TABLE public.gtd_actions
  ADD COLUMN IF NOT EXISTS priority TEXT NULL;

COMMENT ON COLUMN public.gtd_actions.priority IS 'Prioridade: high (alta), med (média), low (baixa).';

CREATE INDEX IF NOT EXISTS idx_gtd_actions_priority ON public.gtd_actions(user_id, priority) WHERE priority IS NOT NULL;

NOTIFY pgrst, 'reload schema';
