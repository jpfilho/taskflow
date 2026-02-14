-- Rotina (tarefas recorrentes) e alarmes para gtd_actions
-- recurrence_rule: 'daily' | 'weekly' | 'monthly'
-- recurrence_weekdays: para weekly, dias da semana (0=dom, 1=seg, ...) separados por vírgula, ex: '1,3,5'

ALTER TABLE public.gtd_actions
  ADD COLUMN IF NOT EXISTS is_routine BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recurrence_rule TEXT,
  ADD COLUMN IF NOT EXISTS recurrence_weekdays TEXT,
  ADD COLUMN IF NOT EXISTS alarm_at TIMESTAMPTZ;

COMMENT ON COLUMN public.gtd_actions.is_routine IS 'Tarefa de rotina (recorrente)';
COMMENT ON COLUMN public.gtd_actions.recurrence_rule IS 'Regra: daily, weekly, monthly';
COMMENT ON COLUMN public.gtd_actions.recurrence_weekdays IS 'Para weekly: 0=dom,1=seg,...,6=sáb, ex: 1,3,5';
COMMENT ON COLUMN public.gtd_actions.alarm_at IS 'Data/hora do alarme (lembrete)';

CREATE INDEX IF NOT EXISTS idx_gtd_actions_alarm_at ON public.gtd_actions(user_id, alarm_at) WHERE alarm_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_gtd_actions_is_routine ON public.gtd_actions(user_id, is_routine) WHERE is_routine = true;

NOTIFY pgrst, 'reload schema';
