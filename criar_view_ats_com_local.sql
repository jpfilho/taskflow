-- Cria a view ats_com_local, análoga à notas_sap_com_local, associando ATs ao campo 'local' da tabela locais
-- Regra: usa locais.local_instalacao_sap para localizar dentro de ats.local_instalacao

DROP VIEW IF EXISTS public.ats_com_local CASCADE;

CREATE VIEW public.ats_com_local AS
SELECT
  a.*,
  l.local
FROM public.ats a
LEFT JOIN public.locais l ON
  l.local_instalacao_sap IS NOT NULL
  AND TRIM(l.local_instalacao_sap) != ''
  AND a.local_instalacao IS NOT NULL
  AND a.local_instalacao LIKE '%' || l.local_instalacao_sap || '%';

COMMENT ON VIEW public.ats_com_local IS
'VIEW que retorna todas as ATs com coluna adicional "local", mapeada a partir de locais.local_instalacao_sap quando contida em ats.local_instalacao.';

-- Opcional: recarregar schema do PostgREST
-- NOTIFY pgrst, ''reload schema'';
