-- Delegar ação para outro usuário (ID da tabela usuarios).
ALTER TABLE public.gtd_actions
  ADD COLUMN IF NOT EXISTS delegated_to_user_id TEXT NULL;

COMMENT ON COLUMN public.gtd_actions.delegated_to_user_id IS 'ID do usuário a quem a ação foi delegada (tabela usuarios).';

CREATE INDEX IF NOT EXISTS idx_gtd_actions_delegated_to ON public.gtd_actions(delegated_to_user_id) WHERE delegated_to_user_id IS NOT NULL;

NOTIFY pgrst, 'reload schema';
