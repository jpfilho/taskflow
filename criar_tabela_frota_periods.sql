-- Tabela para períodos específicos por frota em cada tarefa
create table if not exists public.frota_periods (
    id uuid primary key default uuid_generate_v4(),
    task_id uuid not null references public.tasks(id) on delete cascade,
    frota_id uuid not null references public.frota(id) on delete cascade,
    frota_nome text,
    data_inicio timestamptz not null,
    data_fim timestamptz not null,
    tipo text default 'EXECUCAO',
    tipo_periodo text default 'EXECUCAO',
    label text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_frota_periods_task on public.frota_periods(task_id);
create index if not exists idx_frota_periods_frota on public.frota_periods(frota_id);
create index if not exists idx_frota_periods_range on public.frota_periods(task_id, data_inicio, data_fim);

comment on table public.frota_periods is 'Períodos específicos por frota vinculados a tarefas';

notify pgrst, 'reload schema';
