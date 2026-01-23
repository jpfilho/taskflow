-- Corrige políticas de RLS para frota_periods (leitura e escrita)

alter table if exists public.frota_periods enable row level security;

-- SELECT
drop policy if exists "select frota_periods contagem" on public.frota_periods;
create policy "select frota_periods contagem"
  on public.frota_periods
  for select
  to authenticated
  using (true);

drop policy if exists "select frota_periods service" on public.frota_periods;
create policy "select frota_periods service"
  on public.frota_periods
  for select
  to service_role
  using (true);

-- INSERT
drop policy if exists "insert frota_periods contagem" on public.frota_periods;
create policy "insert frota_periods contagem"
  on public.frota_periods
  for insert
  to authenticated
  with check (true);

drop policy if exists "insert frota_periods service" on public.frota_periods;
create policy "insert frota_periods service"
  on public.frota_periods
  for insert
  to service_role
  with check (true);

-- UPDATE
drop policy if exists "update frota_periods contagem" on public.frota_periods;
create policy "update frota_periods contagem"
  on public.frota_periods
  for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "update frota_periods service" on public.frota_periods;
create policy "update frota_periods service"
  on public.frota_periods
  for update
  to service_role
  using (true)
  with check (true);

-- DELETE
drop policy if exists "delete frota_periods contagem" on public.frota_periods;
create policy "delete frota_periods contagem"
  on public.frota_periods
  for delete
  to authenticated
  using (true);

drop policy if exists "delete frota_periods service" on public.frota_periods;
create policy "delete frota_periods service"
  on public.frota_periods
  for delete
  to service_role
  using (true);

-- Recarregar schema do PostgREST
notify pgrst, 'reload schema';
