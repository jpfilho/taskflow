-- Ajuste completo de RLS e permissões para frota_periods
-- Permite SELECT/INSERT/UPDATE/DELETE para anon, authenticated e service_role
-- e recarrega o schema do PostgREST.

-- Garantir permissões de GRANT (RLS não substitui GRANT)
grant select, insert, update, delete on public.frota_periods to anon;
grant select, insert, update, delete on public.frota_periods to authenticated;
grant select, insert, update, delete on public.frota_periods to service_role;

-- Habilitar RLS
alter table if exists public.frota_periods enable row level security;

-- Remover políticas antigas
drop policy if exists "select frota_periods contagem" on public.frota_periods;
drop policy if exists "select frota_periods service" on public.frota_periods;
drop policy if exists "select frota_periods anon" on public.frota_periods;
drop policy if exists "select frota_periods authenticated" on public.frota_periods;
drop policy if exists "insert frota_periods contagem" on public.frota_periods;
drop policy if exists "insert frota_periods service" on public.frota_periods;
drop policy if exists "insert frota_periods anon" on public.frota_periods;
drop policy if exists "insert frota_periods authenticated" on public.frota_periods;
drop policy if exists "update frota_periods contagem" on public.frota_periods;
drop policy if exists "update frota_periods service" on public.frota_periods;
drop policy if exists "update frota_periods anon" on public.frota_periods;
drop policy if exists "update frota_periods authenticated" on public.frota_periods;
drop policy if exists "delete frota_periods contagem" on public.frota_periods;
drop policy if exists "delete frota_periods service" on public.frota_periods;
drop policy if exists "delete frota_periods anon" on public.frota_periods;
drop policy if exists "delete frota_periods authenticated" on public.frota_periods;

-- SELECT
create policy "select frota_periods anon"
  on public.frota_periods
  for select
  to anon
  using (true);

create policy "select frota_periods authenticated"
  on public.frota_periods
  for select
  to authenticated
  using (true);

create policy "select frota_periods service"
  on public.frota_periods
  for select
  to service_role
  using (true);

-- INSERT
create policy "insert frota_periods anon"
  on public.frota_periods
  for insert
  to anon
  with check (true);

create policy "insert frota_periods authenticated"
  on public.frota_periods
  for insert
  to authenticated
  with check (true);

create policy "insert frota_periods service"
  on public.frota_periods
  for insert
  to service_role
  with check (true);

-- UPDATE
create policy "update frota_periods anon"
  on public.frota_periods
  for update
  to anon
  using (true)
  with check (true);

create policy "update frota_periods authenticated"
  on public.frota_periods
  for update
  to authenticated
  using (true)
  with check (true);

create policy "update frota_periods service"
  on public.frota_periods
  for update
  to service_role
  using (true)
  with check (true);

-- DELETE
create policy "delete frota_periods anon"
  on public.frota_periods
  for delete
  to anon
  using (true);

create policy "delete frota_periods authenticated"
  on public.frota_periods
  for delete
  to authenticated
  using (true);

create policy "delete frota_periods service"
  on public.frota_periods
  for delete
  to service_role
  using (true);

-- Recarregar schema
notify pgrst, 'reload schema';
