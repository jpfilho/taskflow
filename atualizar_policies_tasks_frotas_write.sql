-- Libera INSERT/UPDATE/DELETE em tasks_frotas e frota_periods (além de SELECT) para role authenticated

-- tasks_frotas
alter table if exists public.tasks_frotas enable row level security;

drop policy if exists "select tasks_frotas contagem" on public.tasks_frotas;
create policy "select tasks_frotas contagem"
  on public.tasks_frotas
  for select
  to authenticated
  using (true);

drop policy if exists "insert tasks_frotas contagem" on public.tasks_frotas;
create policy "insert tasks_frotas contagem"
  on public.tasks_frotas
  for insert
  to authenticated
  with check (true);

drop policy if exists "update tasks_frotas contagem" on public.tasks_frotas;
create policy "update tasks_frotas contagem"
  on public.tasks_frotas
  for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "delete tasks_frotas contagem" on public.tasks_frotas;
create policy "delete tasks_frotas contagem"
  on public.tasks_frotas
  for delete
  to authenticated
  using (true);

-- frota_periods
alter table if exists public.frota_periods enable row level security;

drop policy if exists "select frota_periods contagem" on public.frota_periods;
create policy "select frota_periods contagem"
  on public.frota_periods
  for select
  to authenticated
  using (true);

drop policy if exists "insert frota_periods contagem" on public.frota_periods;
create policy "insert frota_periods contagem"
  on public.frota_periods
  for insert
  to authenticated
  with check (true);

drop policy if exists "update frota_periods contagem" on public.frota_periods;
create policy "update frota_periods contagem"
  on public.frota_periods
  for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "delete frota_periods contagem" on public.frota_periods;
create policy "delete frota_periods contagem"
  on public.frota_periods
  for delete
  to authenticated
  using (true);

-- Recarregar schema do PostgREST
notify pgrst, 'reload schema';
