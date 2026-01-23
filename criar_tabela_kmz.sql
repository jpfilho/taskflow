-- Tabela para arquivos KMZ/KML vinculados a regional e divisão
create table if not exists public.kmz_arquivos (
    id uuid primary key default gen_random_uuid(),
    nome text not null,
    storage_path text not null, -- caminho/URL no bucket de arquivos
    regional_id uuid not null,
    divisao_id uuid not null,
    criado_em timestamptz not null default now(),
    constraint fk_kmz_regional foreign key (regional_id) references public.regionais(id) on delete restrict,
    constraint fk_kmz_divisao foreign key (divisao_id) references public.divisoes(id) on delete restrict
);

-- Elementos (placemarks) extraídos do KMZ/KML
create table if not exists public.kmz_features (
    id uuid primary key default gen_random_uuid(),
    kmz_id uuid not null references public.kmz_arquivos(id) on delete cascade,
    nome text not null,
    descricao text,
    is_line boolean not null default false,
    coords jsonb not null, -- lista de pontos [{ "lat": -15.7, "lng": -47.8 }, ...]
    criado_em timestamptz not null default now()
);

create index if not exists idx_kmz_features_kmz on public.kmz_features(kmz_id);
create index if not exists idx_kmz_arquivos_regional_divisao on public.kmz_arquivos(regional_id, divisao_id);
