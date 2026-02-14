-- Rastrear de qual captura (inbox) cada ação foi gerada.
ALTER TABLE public.gtd_actions
  ADD COLUMN IF NOT EXISTS source_inbox_id UUID NULL REFERENCES public.gtd_inbox(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.gtd_actions.source_inbox_id IS 'ID do item do inbox que originou esta ação (ao processar).';

CREATE INDEX IF NOT EXISTS idx_gtd_actions_source_inbox ON public.gtd_actions(source_inbox_id) WHERE source_inbox_id IS NOT NULL;

NOTIFY pgrst, 'reload schema';
