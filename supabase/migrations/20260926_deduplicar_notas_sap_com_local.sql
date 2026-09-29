-- ==============================================================================
-- MIGRATION: 20260926_deduplicar_notas_sap_com_local.sql
-- MOTIVO: Correção de cardinalidade 1:N no relacionamento entre notas_sap e locais.
-- PROBLEMA ORIGINAL:
--   O LEFT JOIN original entre notas_sap e locais utilizava LIKE substring sem
--   desempate ou limite. Quando um mesmo código de instalação SAP era cadastrado
--   por mais de uma Regional (ex: Linhas de Transmissão interestaduais com
--   IBDSBD U1 / Teresina e IBD/SBD 04L1 / Fortaleza) ou quando haviam cadastros
--   setoriais, a Nota SAP era multiplicada N vezes, inflando contagens, quebrando
--   a paginação e gerando duplicatas visuais.
--
-- ARQUITETURA DA SOLUÇÃO:
--   1. Determinação determinística e exata da estrutura organizacional da Nota:
--      notas_sap.centro_trabalho_responsavel -> centros_trabalho (match exato, LIMIT 1).
--   2. Busca e ranking determinístico dos locais compatíveis:
--      Prioridade 0: Match Organizacional Total (Regional + Divisão + Segmento)
--      Prioridade 1: Match Regional + Divisão
--      Prioridade 2: Match Regional + Segmento
--      Prioridade 3: Match Regional
--      Prioridade 4: Match Divisão + Segmento
--      Prioridade 5: Match Segmento
--      Prioridade 6: Sem aderência organizacional direta
--      Critério de especificidade: LENGTH(local_instalacao_sap) DESC
--      Desempate determinístico: loc.id ASC
--      Seleção: LIMIT 1 (garante cardinalidade estrita 1:1 por Nota).
--
-- ROLLBACK DISPONÍVEL AO FINAL DO ARQUIVO.
-- ==============================================================================

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
FROM
  public.notas_sap ns

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

COMMENT ON VIEW public.notas_sap_com_local IS 
'VIEW que retorna todas as notas SAP com cardinalidade estrita 1:1, resolvendo o local compatível por ranking organizacional (Regional/Divisão/Segmento) e especificidade de código SAP.';

-- Garantir permissões de acesso
GRANT SELECT ON public.notas_sap_com_local TO authenticated;
GRANT SELECT ON public.notas_sap_com_local TO anon;

-- Recarregar o schema do PostgREST
NOTIFY pgrst, 'reload schema';

-- ==============================================================================
-- ROLLBACK DEFINITION (Caso seja necessário restaurar a versão anterior):
-- ==============================================================================
-- CREATE OR REPLACE VIEW public.notas_sap_com_local AS
-- SELECT 
--   ns.*,
--   l.local
-- FROM public.notas_sap ns
-- LEFT JOIN public.locais l ON 
--   l.local_instalacao_sap IS NOT NULL 
--   AND TRIM(l.local_instalacao_sap) != ''
--   AND ns.local_instalacao IS NOT NULL
--   AND ns.local_instalacao LIKE '%' || l.local_instalacao_sap || '%';
-- NOTIFY pgrst, 'reload schema';
