-- Habilitar PostGIS (se não estiver ativo) e criar view para geometria do KMZ
CREATE EXTENSION IF NOT EXISTS postgis;

-- View que converte coords (jsonb) em geometry, sem alterar kmz_features
CREATE OR REPLACE VIEW public.vw_kmz_geoms AS
SELECT
  k.id,
  k.kmz_id,
  k.nome,
  k.descricao,
  k.is_line,
  k.coords,
  CASE
    WHEN k.is_line = false THEN
      ST_SetSRID(
        ST_MakePoint(
          COALESCE((k.coords->>'lon')::float, (k.coords->>'lng')::float),
          (k.coords->>'lat')::float
        ), 4326
      )
    ELSE
      ST_SetSRID(
        ST_MakeLine(
          ARRAY(
            SELECT ST_MakePoint(
              COALESCE((p->>'lon')::float, (p->>'lng')::float),
              (p->>'lat')::float
            )
            FROM jsonb_array_elements(k.coords) p
          )
        ), 4326
      )
  END AS geom
FROM public.kmz_features k;

-- Para indexar, crie um materialized view ou use índices na tabela base.
-- Se precisar de performance extra, opção:
-- CREATE MATERIALIZED VIEW public.mv_kmz_geoms AS SELECT * FROM public.vw_kmz_geoms;
-- CREATE INDEX IF NOT EXISTS idx_mv_kmz_geoms_geom ON public.mv_kmz_geoms USING GIST (geom);
-- (e refresh conforme necessidade)
