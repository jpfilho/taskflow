-- Tabela de focos de queimadas (INPE Dataserver COIDS)
CREATE TABLE IF NOT EXISTS public.tbl_queimadas_focos (
  id TEXT PRIMARY KEY, -- hash natural (lat, lon, acq_time, sat)
  source TEXT NOT NULL DEFAULT 'inpe_dataserver',
  acq_time TIMESTAMPTZ NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  raw JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice por tempo
CREATE INDEX IF NOT EXISTS idx_tbl_queimadas_focos_time ON public.tbl_queimadas_focos(acq_time DESC);

-- PostGIS opcional
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
    ALTER TABLE public.tbl_queimadas_focos
      ADD COLUMN IF NOT EXISTS geom geography(Point, 4326);
    CREATE INDEX IF NOT EXISTS idx_tbl_queimadas_focos_geom ON public.tbl_queimadas_focos USING GIST(geom);
  END IF;
END$$;

COMMENT ON TABLE public.tbl_queimadas_focos IS 'Focos de queimadas (INPE Dataserver COIDS)';
