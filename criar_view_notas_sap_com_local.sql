-- Criar VIEW que retorna notas_sap com coluna 'local' calculada automaticamente
-- A coluna 'local' será preenchida quando local_instalacao_sap da tabela locais
-- estiver contido no local_instalacao da nota SAP

-- Remover a VIEW se já existir
DROP VIEW IF EXISTS public.notas_sap_com_local;

-- Criar a VIEW
CREATE OR REPLACE VIEW public.notas_sap_com_local AS
SELECT 
  ns.id,
  ns.tipo,
  ns.criado_em,
  ns.text_prioridade,
  ns.nota,
  ns.ordem,
  ns.descricao,
  ns.local_instalacao,
  ns.sala,
  ns.status_sistema,
  ns.inicio_desejado,
  ns.conclusao_desejada,
  ns.hora_criacao,
  ns.status_usuario,
  ns.equipamento,
  ns.data,
  ns.notificacao,
  ns.centro_trabalho_responsavel,
  ns.centro,
  ns.fim_avaria,
  ns.de,
  ns.encerramento,
  ns.denominacao_executor,
  ns.data_referencia,
  ns.gpm,
  ns.inicio_avaria,
  ns.modificado_em,
  ns.campo_ordenacao,
  ns.data_importacao,
  ns.created_at,
  ns.updated_at,
  ns.detalhes,
  l.local
FROM public.notas_sap ns

  -- ETAPA 1: Determinar ESTRITAMENTE 1 centro de trabalho da Nota (Match Exato)
  LEFT JOIN LATERAL (
    SELECT
      ct.regional_id,
      ct.divisao_id,
      ct.segmento_id
    FROM public.centros_trabalho ct
    WHERE
      ct.ativo = TRUE
      AND UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
    ORDER BY ct.id ASC
    LIMIT 1
  ) ct_nota ON TRUE

  -- ETAPA 2: Buscar e ranquear locais compatíveis, selecionando ESTRITAMENTE 1 Local
  LEFT JOIN LATERAL (
    SELECT
      loc.local
    FROM public.locais loc
    WHERE
      loc.local_instalacao_sap IS NOT NULL
      AND TRIM(loc.local_instalacao_sap) <> ''
      AND ns.local_instalacao IS NOT NULL
      AND ns.local_instalacao LIKE '%' || loc.local_instalacao_sap || '%'
    ORDER BY
      -- 1. Match Organizacional com prioridade estrutural da Regional
      CASE
        WHEN ct_nota.regional_id IS NOT NULL 
         AND loc.regional_id = ct_nota.regional_id
         AND loc.divisao_id = ct_nota.divisao_id
         AND loc.segmento_id = ct_nota.segmento_id
          THEN 0
        WHEN ct_nota.regional_id IS NOT NULL 
         AND loc.regional_id = ct_nota.regional_id
         AND loc.divisao_id = ct_nota.divisao_id
          THEN 1
        WHEN ct_nota.regional_id IS NOT NULL 
         AND loc.regional_id = ct_nota.regional_id
         AND loc.segmento_id = ct_nota.segmento_id
          THEN 2
        WHEN ct_nota.regional_id IS NOT NULL 
         AND loc.regional_id = ct_nota.regional_id
          THEN 3
        WHEN ct_nota.divisao_id IS NOT NULL 
         AND loc.divisao_id = ct_nota.divisao_id
         AND loc.segmento_id = ct_nota.segmento_id
          THEN 4
        WHEN ct_nota.segmento_id IS NOT NULL 
         AND loc.segmento_id = ct_nota.segmento_id
          THEN 5
        ELSE 6
      END ASC,
      -- 2. Especificidade do Código SAP
      LENGTH(loc.local_instalacao_sap) DESC,
      -- 3. Desempate determinístico
      loc.id ASC
    LIMIT 1
  ) l ON TRUE;

-- Comentário na VIEW
COMMENT ON VIEW public.notas_sap_com_local IS 
'VIEW que retorna todas as notas SAP com cardinalidade estrita 1:1, resolvendo o local compatível por ranking organizacional (Regional/Divisão/Segmento) e especificidade de código SAP.';

-- Garantir permissões (ajustar conforme necessário)
GRANT SELECT ON public.notas_sap_com_local TO authenticated;
GRANT SELECT ON public.notas_sap_com_local TO anon;

-- Recarregar o schema do PostgREST
NOTIFY pgrst, 'reload schema';

-- Exemplo de uso:
-- SELECT * FROM notas_sap_com_local WHERE local IS NOT NULL LIMIT 10;
