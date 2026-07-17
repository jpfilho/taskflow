-- Migration para criar tabelas do módulo de Demandas Operacionais
-- Criado em: 2026-07-08

-- 1. Criar Tabela Principal de Demandas
create table if not exists public.demandas (
    id uuid primary key default gen_random_uuid(),
    origem text not null,
    local text not null,
    sala text,
    demanda text not null,
    nota text,
    ordem text,
    si text,
    at text,
    responsavel text not null,
    prazo date not null,
    status text not null default 'Aberta',
    prioridade text not null default 'Normal',
    observacoes text,
    data_conclusao timestamptz,
    created_by uuid,
    updated_by uuid,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    -- Constraints Check
    constraint check_demandas_status check (status in (
        'Aberta', 
        'Em análise', 
        'Programada', 
        'Em execução', 
        'Aguardando terceiros', 
        'Aguardando material', 
        'Concluída', 
        'Cancelada', 
        'Suspensa'
    )),
    constraint check_demandas_prioridade check (prioridade in (
        'Baixa',
        'Normal',
        'Alta',
        'Crítica'
    ))
);

-- 2. Criar Tabela de Anexos
create table if not exists public.demanda_anexos (
    id uuid primary key default gen_random_uuid(),
    demanda_id uuid not null references public.demandas(id) on delete cascade,
    tipo text not null,
    file_name text not null,
    file_path text not null,
    file_url text,
    mime_type text,
    file_size bigint,
    created_by uuid,
    created_at timestamptz not null default now(),

    -- Constraints Check
    constraint check_demanda_anexos_tipo check (tipo in (
        'evidencia_antes',
        'evidencia_depois',
        'anexo_geral'
    ))
);

-- 3. Criar Tabela de Histórico
create table if not exists public.demanda_historico (
    id uuid primary key default gen_random_uuid(),
    demanda_id uuid not null references public.demandas(id) on delete cascade,
    campo text,
    valor_anterior text,
    valor_novo text,
    observacao text,
    created_by uuid,
    created_at timestamptz not null default now()
);

-- 4. Criar Índices de Performance
create index if not exists idx_demandas_status on public.demandas(status);
create index if not exists idx_demandas_prazo on public.demandas(prazo);
create index if not exists idx_demandas_local on public.demandas(local);
create index if not exists idx_demandas_responsavel on public.demandas(responsavel);
create index if not exists idx_demandas_created_at on public.demandas(created_at);
create index if not exists idx_demanda_anexos_demanda_id on public.demanda_anexos(demanda_id);
create index if not exists idx_demanda_anexos_tipo on public.demanda_anexos(tipo);
create index if not exists idx_demanda_historico_demanda_id on public.demanda_historico(demanda_id);

-- 5. Trigger para Atualização Automática de updated_at nas demandas
create or replace function public.handle_update_timestamp()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger trigger_update_demandas_timestamp
    before update on public.demandas
    for each row
    execute function public.handle_update_timestamp();

-- 6. Desabilitar RLS (Row Level Security) para compatibilidade com AuthServiceSimples do TaskFlow
alter table public.demandas disable row level security;
alter table public.demanda_anexos disable row level security;
alter table public.demanda_historico disable row level security;

