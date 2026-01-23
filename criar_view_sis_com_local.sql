-- Cria a view sis_com_local, análoga às views de notas e ATs, adicionando coluna "local"
-- Regra: usa locais.local_instalacao_sap contido em sis.local_instalacao

DROP VIEW IF EXISTS public.sis_com_local CASCADE;

CREATE VIEW public.sis_com_local AS
SELECT
  s.*,
  l.local
FROM public.sis s
LEFT JOIN public.locais l ON
  l.local_instalacao_sap IS NOT NULL
  AND TRIM(l.local_instalacao_sap) != ''
  AND s.local_instalacao IS NOT NULL
  AND s.local_instalacao LIKE '%' || l.local_instalacao_sap || '%';

COMMENT ON VIEW public.sis_com_local IS
'VIEW que retorna todas as SIs com coluna adicional "local", mapeada a partir de locais.local_instalacao_sap quando contida em sis.local_instalacao.';

-- Opcional: recarregar schema do PostgREST
-- NOTIFY pgrst, ''reload schema'';
