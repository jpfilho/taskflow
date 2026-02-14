-- ============================================
-- MIGRATION: EVENTOS DE QUEIMADAS E RAIOS (INPE)
-- ============================================
-- Objetivo:
--  - Habilitar PostGIS (caso não esteja ativo).
--  - Criar tabelas de eventos pontuais (queimadas e raios) com deduplicação.
--  - Criar tabela de geometrias de trechos/faixas para cruzamento espacial.
--  - Criar tabela de agregados por trecho + funções de upsert e refresh.
-- ============================================

-- 0) EXTENSÕES
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1) TABELAS DE EVENTOS PONTUAIS
CREATE TABLE IF NOT EXISTS public.eventos_queimadas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fonte TEXT NOT NULL, -- ex: 'INPE-QUEIMADAS'
  data_hora TIMESTAMPTZ NOT NULL,
  atributos JSONB NOT NULL DEFAULT '{}'::jsonb,
  geom GEOGRAPHY(Point, 4326) NOT NULL,
  lat DOUBLE PRECISION,
  lon DOUBLE PRECISION,
  hash_dedup TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT eventos_queimadas_uniq_hash UNIQUE (hash_dedup)
);

CREATE INDEX IF NOT EXISTS idx_eventos_queimadas_data_hora ON public.eventos_queimadas(data_hora DESC);
CREATE INDEX IF NOT EXISTS idx_eventos_queimadas_geom ON public.eventos_queimadas USING GIST(geom);

CREATE TABLE IF NOT EXISTS public.eventos_raios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fonte TEXT NOT NULL, -- ex: 'ELAT' ou fonte pública equivalente
  data_hora TIMESTAMPTZ NOT NULL,
  atributos JSONB NOT NULL DEFAULT '{}'::jsonb,
  geom GEOGRAPHY(Point, 4326) NOT NULL,
  lat DOUBLE PRECISION,
  lon DOUBLE PRECISION,
  hash_dedup TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT eventos_raios_uniq_hash UNIQUE (hash_dedup)
);

CREATE INDEX IF NOT EXISTS idx_eventos_raios_data_hora ON public.eventos_raios(data_hora DESC);
CREATE INDEX IF NOT EXISTS idx_eventos_raios_geom ON public.eventos_raios USING GIST(geom);

-- 2) TABELA DE GEOMETRIAS DE TRECHOS/FAIXAS
CREATE TABLE IF NOT EXISTS public.trechos_geoms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ref_type TEXT NOT NULL DEFAULT 'TASK', -- TASK, KMZ_FEATURE, etc.
  ref_id UUID NOT NULL, -- id da entidade de referência (tarefa/grupo/feature)
  nome TEXT,
  buffer_m INTEGER NOT NULL DEFAULT 50, -- raio padrão para cruzamento
  geom GEOMETRY(LineString, 4326) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT trechos_geoms_unique_ref UNIQUE (ref_type, ref_id)
);

CREATE INDEX IF NOT EXISTS idx_trechos_geoms_geom ON public.trechos_geoms USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_trechos_geoms_ref ON public.trechos_geoms(ref_type, ref_id);

-- 3) TABELA DE AGREGAÇÃO POR TRECHO
CREATE TABLE IF NOT EXISTS public.eventos_agregados_trecho (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trecho_geom_id UUID NOT NULL REFERENCES public.trechos_geoms(id) ON DELETE CASCADE,
  tipo_evento TEXT NOT NULL CHECK (tipo_evento IN ('queimada', 'raio')),
  window_days INTEGER NOT NULL DEFAULT 7,
  total INTEGER NOT NULL DEFAULT 0,
  ultimo_evento TIMESTAMPTZ,
  distancia_min_m DOUBLE PRECISION,
  last_event_hash TEXT,
  last_notified_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT eventos_agregados_trecho_unique UNIQUE (trecho_geom_id, tipo_evento, window_days)
);

CREATE INDEX IF NOT EXISTS idx_eventos_agregados_tipo_window ON public.eventos_agregados_trecho(tipo_evento, window_days);
CREATE INDEX IF NOT EXISTS idx_eventos_agregados_ultimo_evento ON public.eventos_agregados_trecho(ultimo_evento DESC NULLS LAST);

-- 4) FUNÇÕES DE UPSERT IDÔMPOTENTE
CREATE OR REPLACE FUNCTION public.upsert_evento_queimada(
  p_fonte TEXT,
  p_data_hora TIMESTAMPTZ,
  p_geom GEOGRAPHY,
  p_atributos JSONB DEFAULT '{}'::jsonb
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_hash TEXT;
  v_id UUID;
BEGIN
  v_hash := md5(
    concat_ws(
      '|',
      coalesce(p_fonte, ''),
      extract(epoch from p_data_hora)::bigint,
      ST_X(p_geom::geometry),
      ST_Y(p_geom::geometry)
    )
  );

  INSERT INTO public.eventos_queimadas (fonte, data_hora, geom, atributos, hash_dedup, lat, lon)
  VALUES (
    p_fonte,
    p_data_hora,
    p_geom,
    coalesce(p_atributos, '{}'::jsonb),
    v_hash,
    ST_Y(p_geom::geometry),
    ST_X(p_geom::geometry)
  )
  ON CONFLICT (hash_dedup) DO UPDATE
    SET atributos = excluded.atributos,
        lat = excluded.lat,
        lon = excluded.lon
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_evento_raio(
  p_fonte TEXT,
  p_data_hora TIMESTAMPTZ,
  p_geom GEOGRAPHY,
  p_atributos JSONB DEFAULT '{}'::jsonb
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_hash TEXT;
  v_id UUID;
BEGIN
  v_hash := md5(
    concat_ws(
      '|',
      coalesce(p_fonte, ''),
      extract(epoch from p_data_hora)::bigint,
      ST_X(p_geom::geometry),
      ST_Y(p_geom::geometry)
    )
  );

  INSERT INTO public.eventos_raios (fonte, data_hora, geom, atributos, hash_dedup, lat, lon)
  VALUES (
    p_fonte,
    p_data_hora,
    p_geom,
    coalesce(p_atributos, '{}'::jsonb),
    v_hash,
    ST_Y(p_geom::geometry),
    ST_X(p_geom::geometry)
  )
  ON CONFLICT (hash_dedup) DO UPDATE
    SET atributos = excluded.atributos,
        lat = excluded.lat,
        lon = excluded.lon
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- 5) FUNÇÃO DE REFRESH DE AGREGAÇÃO POR TRECHO
CREATE OR REPLACE FUNCTION public.refresh_eventos_agregados_trecho(
  p_window_days INTEGER DEFAULT 7,
  p_buffer_m INTEGER DEFAULT 50
) RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  -- QUEIMADAS
  INSERT INTO public.eventos_agregados_trecho AS agg (
    trecho_geom_id,
    tipo_evento,
    window_days,
    total,
    ultimo_evento,
    distancia_min_m,
    last_event_hash,
    updated_at
  )
  SELECT
    tg.id AS trecho_geom_id,
    'queimada' AS tipo_evento,
    p_window_days AS window_days,
    COUNT(eq.id) AS total,
    MAX(eq.data_hora) AS ultimo_evento,
    MIN(ST_Distance(eq.geom, tg.geom::geography)) AS distancia_min_m,
    MAX(eq.hash_dedup) AS last_event_hash,
    now() AS updated_at
  FROM public.trechos_geoms tg
  LEFT JOIN public.eventos_queimadas eq
    ON eq.data_hora >= now() - (p_window_days || ' days')::interval
   AND ST_DWithin(eq.geom, tg.geom::geography, p_buffer_m)
  GROUP BY tg.id
  ON CONFLICT (trecho_geom_id, tipo_evento, window_days) DO UPDATE
    SET total = excluded.total,
        ultimo_evento = excluded.ultimo_evento,
        distancia_min_m = excluded.distancia_min_m,
        last_event_hash = excluded.last_event_hash,
        updated_at = now();

  -- RAIOS
  INSERT INTO public.eventos_agregados_trecho AS agg (
    trecho_geom_id,
    tipo_evento,
    window_days,
    total,
    ultimo_evento,
    distancia_min_m,
    last_event_hash,
    updated_at
  )
  SELECT
    tg.id AS trecho_geom_id,
    'raio' AS tipo_evento,
    p_window_days AS window_days,
    COUNT(er.id) AS total,
    MAX(er.data_hora) AS ultimo_evento,
    MIN(ST_Distance(er.geom, tg.geom::geography)) AS distancia_min_m,
    MAX(er.hash_dedup) AS last_event_hash,
    now() AS updated_at
  FROM public.trechos_geoms tg
  LEFT JOIN public.eventos_raios er
    ON er.data_hora >= now() - (p_window_days || ' days')::interval
   AND ST_DWithin(er.geom, tg.geom::geography, p_buffer_m)
  GROUP BY tg.id
  ON CONFLICT (trecho_geom_id, tipo_evento, window_days) DO UPDATE
    SET total = excluded.total,
        ultimo_evento = excluded.ultimo_evento,
        distancia_min_m = excluded.distancia_min_m,
        last_event_hash = excluded.last_event_hash,
        updated_at = now();
END;
$$;

COMMENT ON TABLE public.eventos_queimadas IS 'Eventos de focos de queimada (INPE) armazenados como geografia';
COMMENT ON TABLE public.eventos_raios IS 'Eventos de descargas atmosféricas (raios) armazenados como geografia';
COMMENT ON TABLE public.trechos_geoms IS 'Geometrias (linhas) de faixas/trechos para cruzamento espacial';
COMMENT ON TABLE public.eventos_agregados_trecho IS 'Agregados de eventos por trecho/linha e janela de tempo';
COMMENT ON FUNCTION public.refresh_eventos_agregados_trecho IS 'Recalcula contagens e distâncias mínimas de eventos por trecho';
