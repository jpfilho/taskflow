-- Script para verificar por que Média, Urgência e Alta não estão funcionando

-- 1. Verificar regras para Média, Urgência e Alta
SELECT 
    rpn.id,
    rpn.prioridade,
    UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as prioridade_normalizada,
    rpn.dias_prazo,
    rpn.data_referencia,
    rpn.ativo,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS ESPECÍFICOS'
        ELSE 'SEM SEGMENTOS (APLICA A TODOS)'
    END as tipo_regra,
    (
        SELECT string_agg(s.segmento, ', ')
        FROM regras_prazo_notas_segmentos rpns
        INNER JOIN segmentos s ON s.id = rpns.segmento_id
        WHERE rpns.regra_prazo_nota_id = rpn.id
    ) as segmentos_da_regra
FROM regras_prazo_notas rpn
WHERE rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) IN ('MEDIA', 'URGENCIA', 'ALTA')
ORDER BY rpn.prioridade, rpn.data_referencia;

-- 2. Pegar uma nota de Média e verificar por que não encontra regra
SELECT 
    ns.nota,
    ns.text_prioridade,
    ns.centro_trabalho_responsavel,
    ns.inicio_desejado,
    ns.criado_em,
    -- Verificar se há regra correspondente (sem considerar segmentos)
    (
        SELECT COUNT(*)
        FROM regras_prazo_notas rpn
        WHERE UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
              UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
          AND rpn.ativo = true
          AND (
              (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
              OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
          )
    ) as regras_encontradas_sem_segmento,
    -- Verificar se há regra sem segmentos específicos
    (
        SELECT COUNT(*)
        FROM regras_prazo_notas rpn
        WHERE UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
              UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
          AND rpn.ativo = true
          AND (
              (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
              OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
          )
          AND NOT EXISTS (
              SELECT 1 FROM regras_prazo_notas_segmentos rpns
              WHERE rpns.regra_prazo_nota_id = rpn.id
          )
    ) as regras_sem_segmentos,
    -- Verificar se o centro de trabalho existe na tabela centros_trabalho
    (
        SELECT COUNT(*)
        FROM centros_trabalho ct
        WHERE ct.ativo = true
          AND (
              UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
              OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
              OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
          )
    ) as centros_trabalho_encontrados,
    -- Verificar segmentos do centro de trabalho
    (
        SELECT string_agg(DISTINCT s.segmento, ', ')
        FROM centros_trabalho ct
        INNER JOIN segmentos s ON s.id = ct.segmento_id
        WHERE ct.ativo = true
          AND (
              UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
              OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
              OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
          )
    ) as segmentos_do_centro
FROM notas_sap_com_prazo ns
WHERE UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND ns.data_vencimento IS NULL
ORDER BY ns.nota
LIMIT 10;

-- 3. Comparar com Monitoramento (que funciona)
SELECT 
    ns.nota,
    ns.text_prioridade,
    ns.centro_trabalho_responsavel,
    ns.inicio_desejado,
    ns.criado_em,
    ns.data_vencimento,
    -- Verificar se há regra correspondente (sem considerar segmentos)
    (
        SELECT COUNT(*)
        FROM regras_prazo_notas rpn
        WHERE UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
              UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
          AND rpn.ativo = true
          AND (
              (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
              OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
          )
    ) as regras_encontradas_sem_segmento,
    -- Verificar se há regra sem segmentos específicos
    (
        SELECT COUNT(*)
        FROM regras_prazo_notas rpn
        WHERE UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
              UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
          AND rpn.ativo = true
          AND (
              (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
              OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
          )
          AND NOT EXISTS (
              SELECT 1 FROM regras_prazo_notas_segmentos rpns
              WHERE rpns.regra_prazo_nota_id = rpn.id
          )
    ) as regras_sem_segmentos
FROM notas_sap_com_prazo ns
WHERE UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MONITORAMENTO'
  AND ns.data_vencimento IS NOT NULL
ORDER BY ns.nota
LIMIT 5;

-- 4. Testar manualmente o cálculo para uma nota de Média
SELECT 
    ns.nota,
    ns.text_prioridade,
    ns.centro_trabalho_responsavel,
    ns.criado_em,
    rpn.prioridade as regra_prioridade,
    rpn.data_referencia,
    rpn.dias_prazo,
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'SEM SEGMENTOS - DEVERIA APLICAR'
        ELSE 'TEM SEGMENTOS'
    END as tipo_regra,
    -- Calcular manualmente
    (ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date as data_vencimento_calculada
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND rpn.ativo = true
  AND rpn.data_referencia = 'criacao'
  AND ns.criado_em IS NOT NULL
ORDER BY ns.nota
LIMIT 5;
