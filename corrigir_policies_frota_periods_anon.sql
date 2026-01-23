-- Políticas extras para permitir acesso com role 'anon' em frota_periods

alter table if exists public.frota_periods enable row level security;

-- SELECT
drop policy if exists "select frota_periods anon" on public.frota_periods;
create policy "select frota_periods anon"
  on public.frota_periods
  for select
  to anon
  using (true);

-- INSERT
drop policy if exists "insert frota_periods anon" on public.frota_periods;
create policy "insert frota_periods anon"
  on public.frota_periods
  for insert
  to anon
  with check (true);

-- UPDATE
drop policy if exists "update frota_periods anon" on public.frota_periods;
create policy "update frota_periods anon"
  on public.frota_periods
  for update
  to anon
  using (true)
  with check (true);

-- DELETE
drop policy if exists "delete frota_periods anon" on public.frota_periods;
create policy "delete frota_periods anon"
  on public.frota_periods
  for delete
  to anon
  using (true);

-- Recarregar schema do PostgREST
notify pgrst, 'reload schema';
