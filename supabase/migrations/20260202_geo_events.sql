-- Tabelas para queimadas e raios + view de geometria dos KMZ
-- Executar no Postgres (supabase-db)

-- 1) Queimadas
CREATE TABLE IF NOT EXISTS public.geo_queimadas (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL DEFAULT 'inpe_dataserver',
  acq_time TIMESTAMPTZ NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  satellite TEXT,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  geom GEOGRAPHY(Point, 4326)
);

CREATE INDEX IF NOT EXISTS idx_geo_queimadas_time ON public.geo_queimadas(acq_time DESC);
CREATE INDEX IF NOT EXISTS idx_geo_queimadas_geom ON public.geo_queimadas USING GIST(geom);

-- 2) Raios
CREATE TABLE IF NOT EXISTS public.geo_raios (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL DEFAULT 'raios_url',
  strike_time TIMESTAMPTZ NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  geom GEOGRAPHY(Point, 4326)
);

CREATE INDEX IF NOT EXISTS idx_geo_raios_time ON public.geo_raios(strike_time DESC);
CREATE INDEX IF NOT EXISTS idx_geo_raios_geom ON public.geo_raios USING GIST(geom);

-- 3) View de geometria dos KMZ (coords em GeoJSON)
DROP VIEW IF EXISTS public.kmz_features_geom;
CREATE VIEW public.kmz_features_geom AS
SELECT
  k.id,
  k.kmz_id,
  k.nome,
  k.is_line,
  k.coords,
  ST_SetSRID(ST_GeomFromGeoJSON(k.coords::text), 4326) AS geom
FROM public.kmz_features k;

CREATE INDEX IF NOT EXISTS idx_kmz_features_geom_gist ON public.kmz_features USING GIST((ST_SetSRID(ST_GeomFromGeoJSON(coords::text),4326)));

COMMENT ON TABLE public.geo_queimadas IS 'Focos de queimadas ingeridos do Dataserver/INPE (CSV 10min)';
COMMENT ON TABLE public.geo_raios IS 'Eventos de raios de fontes públicas (RAIOS_URL ou Blitzortung/LIMAPS)';
