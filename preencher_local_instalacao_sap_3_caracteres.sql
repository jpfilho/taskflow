-- Preencher automaticamente o campo local_instalacao_sap
-- para todos os locais que têm exatamente 3 caracteres no campo local
-- Seguindo o padrão: H-S-S + código do local (exemplo: BEA -> H-S-SBEA)

UPDATE public.locais
SET 
  local_instalacao_sap = 'H-S-S' || UPPER(local),
  updated_at = NOW()
WHERE 
  -- Apenas locais com exatamente 3 caracteres
  LENGTH(TRIM(local)) = 3
  -- E que ainda não têm o campo preenchido (para não sobrescrever valores existentes)
  AND (local_instalacao_sap IS NULL OR TRIM(local_instalacao_sap) = '');

-- Mostrar quantos registros foram atualizados
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE NOTICE 'Total de registros atualizados: %', v_count;
END $$;

-- Verificar os resultados
SELECT 
  local,
  descricao,
  local_instalacao_sap,
  CASE 
    WHEN LENGTH(TRIM(local)) = 3 THEN 'Atualizado'
    ELSE 'Não atualizado (não tem 3 caracteres)'
  END AS status
FROM public.locais
WHERE LENGTH(TRIM(local)) = 3
ORDER BY local;
