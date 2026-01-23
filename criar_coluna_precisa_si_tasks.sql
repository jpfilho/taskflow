-- Adiciona coluna para marcar se a tarefa precisa de SI
ALTER TABLE public.tasks
ADD COLUMN IF NOT EXISTS precisa_si boolean DEFAULT false;

-- Opcional: garantir default aplicado a registros existentes
UPDATE public.tasks SET precisa_si = COALESCE(precisa_si, false);

NOTIFY pgrst, 'reload schema';
