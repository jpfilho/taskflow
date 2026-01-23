-- Schema de demandas (Supabase/Postgres)
-- Inclui tabelas, índices e políticas RLS básicas.

-- Tabela de usuários de referência (usa auth.users)
create table if not exists app_users (
  id uuid primary key references auth.users on delete cascade,
  nome text not null,
  email text not null unique,
  created_at timestamptz default now()
);

-- Categorias customizáveis
create table if not exists demand_categories (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  cor text,
  created_at timestamptz default now(),
  created_by uuid references app_users(id)
);

-- Demandas
create table if not exists demands (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  descricao text,
  status text not null check (status in ('pendente','em_progresso','concluido','cancelado')),
  prioridade text not null check (prioridade in ('baixa','media','alta','urgente')),
  categoria_id uuid references demand_categories(id),
  criado_por uuid references app_users(id) default auth.uid(),
  atribuida_para uuid references app_users(id),
  data_criacao timestamptz default now(),
  data_vencimento timestamptz,
  data_inicio timestamptz,
  data_conclusao timestamptz,
  tags text[] default '{}'::text[],
  metadata jsonb default '{}'::jsonb,
  atualizado_em timestamptz default now()
);

-- Histórico de status
create table if not exists demand_status_history (
  id bigserial primary key,
  demanda_id uuid references demands(id) on delete cascade,
  status_anterior text,
  status_novo text,
  mudado_por uuid references app_users(id),
  mudado_em timestamptz default now()
);

-- Anexos (armazenar caminho no Storage; url = path no bucket)
create table if not exists demand_attachments (
  id uuid primary key default gen_random_uuid(),
  demanda_id uuid references demands(id) on delete cascade,
  url text not null, -- caminho no bucket (ex: demandaId/arquivo.ext)
  nome text,
  tamanho_bytes bigint,
  content_type text,
  criado_em timestamptz default now(),
  criado_por uuid references usuarios(id)
);

-- Índices
create index if not exists idx_demands_status on demands(status);
create index if not exists idx_demands_prioridade on demands(prioridade);
create index if not exists idx_demands_categoria on demands(categoria_id);
create index if not exists idx_demands_vence on demands(data_vencimento);
create index if not exists idx_demands_atribuida_para on demands(atribuida_para);

-- Materialized view para busca full-text (permite índice)
drop materialized view if exists demands_search;
create materialized view demands_search as
select d.*,
       to_tsvector('portuguese', coalesce(d.titulo,'') || ' ' || coalesce(d.descricao,'')) ||
       to_tsvector('portuguese', array_to_string(d.tags,' ')) as document
from demands d;

create index if not exists idx_demands_search_gin on demands_search using gin(document);
-- Para manter atualizada, use refresh manual ou job:
-- refresh materialized view concurrently demands_search;

alter table demands enable row level security;

drop policy if exists "demands_select_all" on demands;
create policy "demands_select_all" on demands
  for select using (
    auth.role() = 'service_role'
    or auth.uid() = criado_por
    or auth.uid() = atribuida_para
  );

-- Inserção: qualquer usuário autenticado ou service_role
drop policy if exists "demands_insert_owner_or_service" on demands;
drop policy if exists "demands_insert_any_authenticated" on demands;
create policy "demands_insert_any_authenticated" on demands
  for insert with check (
    auth.role() = 'service_role'
    or auth.uid() is not null -- qualquer usuário autenticado
  );

drop policy if exists "demands_update_owner_or_assignee_or_service" on demands;
create policy "demands_update_owner_or_assignee_or_service" on demands
  for update using (
    auth.role() = 'service_role'
    or auth.uid() = criado_por
    or auth.uid() = atribuida_para
  );

drop policy if exists "demands_delete_owner_or_service" on demands;
create policy "demands_delete_owner_or_service" on demands
  for delete using (
    auth.role() = 'service_role'
    or auth.uid() = criado_por
  );

-- RLS para attachments da demanda
alter table demand_attachments enable row level security;
drop policy if exists "demand_attachments_select" on demand_attachments;
drop policy if exists "demand_attachments_insert" on demand_attachments;
drop policy if exists "demand_attachments_delete" on demand_attachments;

create policy "demand_attachments_select" on demand_attachments
  for select using (
    exists (
      select 1 from demands d
      where d.id = demanda_id
        and (
          auth.role() = 'service_role'
          or auth.uid() = d.criado_por
          or auth.uid() = d.atribuida_para
        )
    )
  );

create policy "demand_attachments_insert" on demand_attachments
  for insert with check (
    exists (
      select 1 from demands d
      where d.id = demanda_id
        and (
          auth.role() = 'service_role'
          or auth.uid() = d.criado_por
          or auth.uid() = d.atribuida_para
        )
    )
  );

create policy "demand_attachments_delete" on demand_attachments
  for delete using (
    exists (
      select 1 from demands d
      where d.id = demanda_id
        and (
          auth.role() = 'service_role'
          or auth.uid() = d.criado_por
        )
    )
  );

-- Storage: criar bucket privado (rodar uma vez)
-- select storage.create_bucket('demands-attachments', public := false);
-- Políticas no storage.objects para o bucket "demands-attachments"
-- (path = demanda_id/arquivo.ext)
-- Leitura
drop policy if exists "demand_files_read" on storage.objects;
create policy "demand_files_read" on storage.objects
  for select using (
    bucket_id = 'demands-attachments'
    and exists (
      select 1 from demands d
      where d.id = split_part(name, '/', 1)::uuid
        and (
          auth.role() = 'service_role'
          or auth.uid() = d.criado_por
          or auth.uid() = d.atribuida_para
        )
    )
  );
-- Upload
drop policy if exists "demand_files_upload" on storage.objects;
create policy "demand_files_upload" on storage.objects
  for insert with check (
    bucket_id = 'demands-attachments'
    and exists (
      select 1 from demands d
      where d.id = split_part(name, '/', 1)::uuid
        and (
          auth.role() = 'service_role'
          or auth.uid() = d.criado_por
          or auth.uid() = d.atribuida_para
        )
    )
  );
-- Delete
drop policy if exists "demand_files_delete" on storage.objects;
create policy "demand_files_delete" on storage.objects
  for delete using (
    bucket_id = 'demands-attachments'
    and exists (
      select 1 from demands d
      where d.id = split_part(name, '/', 1)::uuid
        and (
          auth.role() = 'service_role'
          or auth.uid() = d.criado_por
        )
    )
  );
