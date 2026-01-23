-- Habilitar e criar políticas de SELECT para contagem de frotas (tasks_frotas e frota_periods)

-- tasks_frotas
alter table if exists public.tasks_frotas enable row level security;
drop policy if exists "select tasks_frotas contagem" on public.tasks_frotas;
create policy "select tasks_frotas contagem"
  on public.tasks_frotas
  for select
  to authenticated
  using (true);

-- frota_periods (opcional, para contagem via períodos específicos)
alter table if exists public.frota_periods enable row level security;
drop policy if exists "select frota_periods contagem" on public.frota_periods;
create policy "select frota_periods contagem"
  on public.frota_periods
  for select
  to authenticated
  using (true);

-- Recarregar schema do PostgREST
notify pgrst, 'reload schema';
