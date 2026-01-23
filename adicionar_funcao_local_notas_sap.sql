-- Criar função que retorna o local baseado no local_instalacao_sap
-- Esta função pode ser usada diretamente nas queries ou como coluna computada

-- Remover a função se já existir
DROP FUNCTION IF EXISTS public.get_local_from_nota_sap(UUID);

-- Criar função que retorna o local para uma nota SAP específica
CREATE OR REPLACE FUNCTION public.get_local_from_nota_sap(nota_sap_id UUID)
RETURNS VARCHAR(50)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_local VARCHAR(50);
  v_local_instalacao VARCHAR(200);
BEGIN
  -- Buscar o local_instalacao da nota
  SELECT local_instalacao INTO v_local_instalacao
  FROM public.notas_sap
  WHERE id = nota_sap_id;
  
  -- Se não encontrar ou for NULL, retornar NULL
  IF v_local_instalacao IS NULL OR TRIM(v_local_instalacao) = '' THEN
    RETURN NULL;
  END IF;
  
  -- Buscar o local da tabela locais onde local_instalacao_sap está contido em local_instalacao
  SELECT l.local INTO v_local
  FROM public.locais l
  WHERE l.local_instalacao_sap IS NOT NULL
    AND TRIM(l.local_instalacao_sap) != ''
    AND v_local_instalacao LIKE '%' || l.local_instalacao_sap || '%'
  LIMIT 1; -- Retornar apenas o primeiro match (caso haja múltiplos)
  
  RETURN v_local;
END;
$$;

-- Comentário na função
COMMENT ON FUNCTION public.get_local_from_nota_sap(UUID) IS 
'Retorna o local da tabela locais quando o local_instalacao_sap está contido no local_instalacao da nota SAP.';

-- Exemplo de uso:
-- SELECT 
--   *,
--   get_local_from_nota_sap(id) as local
-- FROM notas_sap;

-- Recarregar o schema do PostgREST
NOTIFY pgrst, 'reload schema';
