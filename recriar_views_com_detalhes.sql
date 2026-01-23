-- Recriar VIEWs para garantir que o campo 'detalhes' esteja incluído
-- Execute este script no Supabase SQL Editor

-- 1. Recriar VIEW notas_sap_com_local (inclui detalhes via ns.*)
DROP VIEW IF EXISTS public.notas_sap_com_prazo CASCADE;
DROP VIEW IF EXISTS public.notas_sap_com_local CASCADE;

-- Recriar notas_sap_com_local
CREATE VIEW public.notas_sap_com_local AS
SELECT 
  ns.*,
  l.local
FROM public.notas_sap ns
LEFT JOIN public.locais l ON 
  l.local_instalacao_sap IS NOT NULL 
  AND TRIM(l.local_instalacao_sap) != ''
  AND ns.local_instalacao IS NOT NULL
  AND ns.local_instalacao LIKE '%' || l.local_instalacao_sap || '%';

COMMENT ON VIEW public.notas_sap_com_local IS 
'VIEW que retorna todas as notas SAP com uma coluna adicional "local" que corresponde ao local da tabela locais quando o local_instalacao_sap está contido no local_instalacao da nota. Inclui o campo detalhes da tabela notas_sap.';

-- 2. Recriar VIEW notas_sap_com_prazo (inclui detalhes via ns.* de notas_sap_com_local)
-- Execute o arquivo criar_view_notas_sap_com_prazo.sql após este script
-- Ou copie o conteúdo completo da VIEW aqui

-- Recarregar o schema do PostgREST
NOTIFY pgrst, 'reload schema';

-- 3. Verificar se o campo detalhes está nas VIEWs
SELECT 'notas_sap_com_local' as view_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'notas_sap_com_local' 
  AND column_name = 'detalhes'
UNION ALL
SELECT 'notas_sap_com_prazo' as view_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'notas_sap_com_prazo' 
  AND column_name = 'detalhes';
