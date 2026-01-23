-- Criar VIEW que retorna notas_sap com coluna 'local' calculada automaticamente
-- A coluna 'local' será preenchida quando local_instalacao_sap da tabela locais
-- estiver contido no local_instalacao da nota SAP

-- Remover a VIEW se já existir
DROP VIEW IF EXISTS public.notas_sap_com_local;

-- Criar a VIEW
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

-- Comentário na VIEW
COMMENT ON VIEW public.notas_sap_com_local IS 
'VIEW que retorna todas as notas SAP com uma coluna adicional "local" que corresponde ao local da tabela locais quando o local_instalacao_sap está contido no local_instalacao da nota.';

-- Garantir permissões (ajustar conforme necessário)
GRANT SELECT ON public.notas_sap_com_local TO authenticated;
GRANT SELECT ON public.notas_sap_com_local TO anon;

-- Recarregar o schema do PostgREST
NOTIFY pgrst, 'reload schema';

-- Exemplo de uso:
-- SELECT * FROM notas_sap_com_local WHERE local IS NOT NULL LIMIT 10;
