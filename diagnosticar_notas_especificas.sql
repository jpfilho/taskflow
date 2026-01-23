-- Script de diagnóstico passo a passo para notas específicas
-- Verifica cada etapa do cálculo de prazo para identificar onde está falhando
-- Execute este script completo para ver todos os passos de ambas as notas

-- ============================================================================
-- NOTA 11501274 - DIAGNÓSTICO COMPLETO
-- ============================================================================

SELECT '═══════════════════════════════════════════════════════════════════════' as separador;
SELECT 'NOTA 11501274 - INÍCIO DO DIAGNÓSTICO' as etapa;
SELECT '═══════════════════════════════════════════════════════════════════════' as separador;

-- PASSO 1: Verificar dados básicos da nota
SELECT 
    'PASSO 1: Dados básicos da nota' as etapa,
    nota,
    text_prioridade,
    UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as prioridade_normalizada,
    centro_trabalho_responsavel,
    criado_em,
    inicio_desejado,
    CASE 
        WHEN inicio_desejado IS NOT NULL THEN 'TEM inicio_desejado - busca regra para inicio_desejado'
        WHEN criado_em IS NOT NULL THEN 'TEM criado_em - busca regra para criacao'
        ELSE 'SEM DATA DE REFERENCIA'
    END as tipo_data_referencia
FROM notas_sap
WHERE nota = '11501274';

-- PASSO 2: Verificar se existem regras para a prioridade desta nota
SELECT 
    'PASSO 2: Regras cadastradas para esta prioridade' as etapa,
    rpn.id,
    rpn.prioridade,
    UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as prioridade_normalizada,
    rpn.dias_prazo,
    rpn.data_referencia,
    rpn.ativo,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS ESPECÍFICOS'
        ELSE 'SEM SEGMENTOS (APLICA A TODOS) ✓'
    END as tipo_regra
FROM regras_prazo_notas rpn
WHERE rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = (
      SELECT UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
      FROM notas_sap
      WHERE nota = '11501274'
  );

-- PASSO 3: Verificar correspondência de prioridade
SELECT 
    'PASSO 3: Correspondência de prioridade' as etapa,
    ns.nota,
    ns.text_prioridade as prioridade_nota,
    UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as nota_normalizada,
    rpn.prioridade as prioridade_regra,
    UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as regra_normalizada,
    CASE 
        WHEN UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
             UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
        THEN 'MATCH ✓'
        ELSE 'NO MATCH ✗'
    END as match_prioridade,
    ns.inicio_desejado,
    ns.criado_em,
    rpn.data_referencia,
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado' THEN 'MATCH ✓'
        WHEN ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao' THEN 'MATCH ✓'
        ELSE 'NO MATCH ✗'
    END as match_data_referencia
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE ns.nota = '11501274'
  AND rpn.ativo = true;

-- PASSO 4: Verificar se o centro de trabalho está na tabela
SELECT 
    'PASSO 4: Centro de trabalho na tabela' as etapa,
    ns.centro_trabalho_responsavel as centro_nota,
    ct.centro_trabalho as centro_tabela,
    CASE 
        WHEN ct.id IS NOT NULL THEN 'ENCONTRADO ✓'
        ELSE 'NÃO ENCONTRADO ✗'
    END as status_centro,
    s.segmento,
    s.id as segmento_id
FROM notas_sap ns
LEFT JOIN centros_trabalho ct ON (
    UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
    OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
    OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
)
AND ct.ativo = true
LEFT JOIN segmentos s ON s.id = ct.segmento_id
WHERE ns.nota = '11501274';

-- PASSO 5: Verificar segmentos das regras e correspondência
SELECT 
    'PASSO 5: Segmentos das regras e correspondência' as etapa,
    rpn.id as regra_id,
    rpn.prioridade,
    rpn.data_referencia,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS'
        ELSE 'SEM SEGMENTOS (DEVERIA APLICAR) ✓'
    END as tipo_regra,
    s.segmento as segmento_da_regra,
    ct.centro_trabalho as centro_do_segmento,
    ns.centro_trabalho_responsavel as centro_da_nota,
    CASE 
        WHEN ct.id IS NOT NULL AND (
            UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
            OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
            OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
        )
        THEN 'CORRESPONDE ✓'
        WHEN ct.id IS NULL THEN 'CENTRO NÃO ENCONTRADO NA TABELA ✗'
        ELSE 'NÃO CORRESPONDE ✗'
    END as status_correspondencia
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
LEFT JOIN regras_prazo_notas_segmentos rpns ON rpns.regra_prazo_nota_id = rpn.id
LEFT JOIN segmentos s ON s.id = rpns.segmento_id
LEFT JOIN centros_trabalho ct ON ct.segmento_id = s.id AND ct.ativo = true
WHERE ns.nota = '11501274'
  AND rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
      UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
  AND (
      (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
      OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
  );

-- PASSO 6: Testar cálculo manual (simular a VIEW)
SELECT 
    'PASSO 6: Cálculo manual (simular VIEW)' as etapa,
    ns.nota,
    ns.text_prioridade,
    ns.centro_trabalho_responsavel,
    ns.inicio_desejado,
    ns.criado_em,
    rpn.prioridade,
    rpn.data_referencia,
    rpn.dias_prazo,
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'SEM SEGMENTOS - DEVERIA APLICAR ✓'
        WHEN EXISTS (
            SELECT 1 
            FROM regras_prazo_notas_segmentos rpns
            WHERE rpns.regra_prazo_nota_id = rpn.id
              AND EXISTS (
                  SELECT 1
                  FROM segmentos s
                  INNER JOIN centros_trabalho ct ON ct.segmento_id = s.id
                  WHERE s.id = rpns.segmento_id
                    AND ct.ativo = true
                    AND (
                        UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
                        OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
                        OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
                    )
              )
        )
        THEN 'SEGMENTO CORRESPONDE - DEVERIA APLICAR ✓'
        ELSE 'SEGMENTO NÃO CORRESPONDE - NÃO APLICA ✗'
    END as status_aplicacao,
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado'
        THEN (ns.inicio_desejado + INTERVAL '1 day' * rpn.dias_prazo)::date
        WHEN ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao'
        THEN (ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date
        ELSE NULL
    END as data_vencimento_calculada
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE ns.nota = '11501274'
  AND rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
      UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
  AND (
      (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
      OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
  )
ORDER BY 
    CASE WHEN NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id) 
         THEN 0 ELSE 1 END;

-- PASSO 7: Verificar o que a VIEW retorna
SELECT 
    'PASSO 7: Resultado da VIEW' as etapa,
    nota,
    text_prioridade,
    centro_trabalho_responsavel,
    criado_em,
    inicio_desejado,
    data_vencimento,
    dias_restantes
FROM notas_sap_com_prazo
WHERE nota = '11501274';

SELECT '═══════════════════════════════════════════════════════════════════════' as separador;
SELECT 'NOTA 11501274 - FIM DO DIAGNÓSTICO' as etapa;
SELECT '═══════════════════════════════════════════════════════════════════════' as separador;

-- ============================================================================
-- NOTA 11500517 - DIAGNÓSTICO COMPLETO
-- ============================================================================

SELECT '═══════════════════════════════════════════════════════════════════════' as separador;
SELECT 'NOTA 11500517 - INÍCIO DO DIAGNÓSTICO' as etapa;
SELECT '═══════════════════════════════════════════════════════════════════════' as separador;

-- PASSO 1: Verificar dados básicos da nota
SELECT 
    'PASSO 1: Dados básicos da nota' as etapa,
    nota,
    text_prioridade,
    UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as prioridade_normalizada,
    centro_trabalho_responsavel,
    criado_em,
    inicio_desejado,
    CASE 
        WHEN inicio_desejado IS NOT NULL THEN 'TEM inicio_desejado - busca regra para inicio_desejado'
        WHEN criado_em IS NOT NULL THEN 'TEM criado_em - busca regra para criacao'
        ELSE 'SEM DATA DE REFERENCIA'
    END as tipo_data_referencia
FROM notas_sap
WHERE nota = '11500517';

-- PASSO 2: Verificar se existem regras para a prioridade desta nota
SELECT 
    'PASSO 2: Regras cadastradas para esta prioridade' as etapa,
    rpn.id,
    rpn.prioridade,
    UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as prioridade_normalizada,
    rpn.dias_prazo,
    rpn.data_referencia,
    rpn.ativo,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS ESPECÍFICOS'
        ELSE 'SEM SEGMENTOS (APLICA A TODOS) ✓'
    END as tipo_regra
FROM regras_prazo_notas rpn
WHERE rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = (
      SELECT UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
      FROM notas_sap
      WHERE nota = '11500517'
  );

-- PASSO 3: Verificar correspondência de prioridade
SELECT 
    'PASSO 3: Correspondência de prioridade' as etapa,
    ns.nota,
    ns.text_prioridade as prioridade_nota,
    UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as nota_normalizada,
    rpn.prioridade as prioridade_regra,
    UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as regra_normalizada,
    CASE 
        WHEN UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
             UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
        THEN 'MATCH ✓'
        ELSE 'NO MATCH ✗'
    END as match_prioridade,
    ns.inicio_desejado,
    ns.criado_em,
    rpn.data_referencia,
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado' THEN 'MATCH ✓'
        WHEN ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao' THEN 'MATCH ✓'
        ELSE 'NO MATCH ✗'
    END as match_data_referencia
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE ns.nota = '11500517'
  AND rpn.ativo = true;

-- PASSO 4: Verificar se o centro de trabalho está na tabela
SELECT 
    'PASSO 4: Centro de trabalho na tabela' as etapa,
    ns.centro_trabalho_responsavel as centro_nota,
    ct.centro_trabalho as centro_tabela,
    CASE 
        WHEN ct.id IS NOT NULL THEN 'ENCONTRADO ✓'
        ELSE 'NÃO ENCONTRADO ✗'
    END as status_centro,
    s.segmento,
    s.id as segmento_id
FROM notas_sap ns
LEFT JOIN centros_trabalho ct ON (
    UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
    OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
    OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
)
AND ct.ativo = true
LEFT JOIN segmentos s ON s.id = ct.segmento_id
WHERE ns.nota = '11500517';

-- PASSO 5: Verificar segmentos das regras e correspondência
SELECT 
    'PASSO 5: Segmentos das regras e correspondência' as etapa,
    rpn.id as regra_id,
    rpn.prioridade,
    rpn.data_referencia,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS'
        ELSE 'SEM SEGMENTOS (DEVERIA APLICAR) ✓'
    END as tipo_regra,
    s.segmento as segmento_da_regra,
    ct.centro_trabalho as centro_do_segmento,
    ns.centro_trabalho_responsavel as centro_da_nota,
    CASE 
        WHEN ct.id IS NOT NULL AND (
            UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
            OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
            OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
        )
        THEN 'CORRESPONDE ✓'
        WHEN ct.id IS NULL THEN 'CENTRO NÃO ENCONTRADO NA TABELA ✗'
        ELSE 'NÃO CORRESPONDE ✗'
    END as status_correspondencia
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
LEFT JOIN regras_prazo_notas_segmentos rpns ON rpns.regra_prazo_nota_id = rpn.id
LEFT JOIN segmentos s ON s.id = rpns.segmento_id
LEFT JOIN centros_trabalho ct ON ct.segmento_id = s.id AND ct.ativo = true
WHERE ns.nota = '11500517'
  AND rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
      UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
  AND (
      (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
      OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
  );

-- PASSO 6: Testar cálculo manual (simular a VIEW)
SELECT 
    'PASSO 6: Cálculo manual (simular VIEW)' as etapa,
    ns.nota,
    ns.text_prioridade,
    ns.centro_trabalho_responsavel,
    ns.inicio_desejado,
    ns.criado_em,
    rpn.prioridade,
    rpn.data_referencia,
    rpn.dias_prazo,
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'SEM SEGMENTOS - DEVERIA APLICAR ✓'
        WHEN EXISTS (
            SELECT 1 
            FROM regras_prazo_notas_segmentos rpns
            WHERE rpns.regra_prazo_nota_id = rpn.id
              AND EXISTS (
                  SELECT 1
                  FROM segmentos s
                  INNER JOIN centros_trabalho ct ON ct.segmento_id = s.id
                  WHERE s.id = rpns.segmento_id
                    AND ct.ativo = true
                    AND (
                        UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
                        OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
                        OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
                    )
              )
        )
        THEN 'SEGMENTO CORRESPONDE - DEVERIA APLICAR ✓'
        ELSE 'SEGMENTO NÃO CORRESPONDE - NÃO APLICA ✗'
    END as status_aplicacao,
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado'
        THEN (ns.inicio_desejado + INTERVAL '1 day' * rpn.dias_prazo)::date
        WHEN ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao'
        THEN (ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date
        ELSE NULL
    END as data_vencimento_calculada
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE ns.nota = '11500517'
  AND rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
      UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
  AND (
      (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
      OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
  )
ORDER BY 
    CASE WHEN NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id) 
         THEN 0 ELSE 1 END;

-- PASSO 7: Verificar o que a VIEW retorna
SELECT 
    'PASSO 7: Resultado da VIEW' as etapa,
    nota,
    text_prioridade,
    centro_trabalho_responsavel,
    criado_em,
    inicio_desejado,
    data_vencimento,
    dias_restantes
FROM notas_sap_com_prazo
WHERE nota = '11500517';

SELECT '═══════════════════════════════════════════════════════════════════════' as separador;
SELECT 'NOTA 11500517 - FIM DO DIAGNÓSTICO' as etapa;
SELECT '═══════════════════════════════════════════════════════════════════════' as separador;

-- ============================================================================
-- RESUMO COMPARATIVO DAS DUAS NOTAS
-- ============================================================================

SELECT '═══════════════════════════════════════════════════════════════════════' as separador;
SELECT 'RESUMO COMPARATIVO' as etapa;
SELECT '═══════════════════════════════════════════════════════════════════════' as separador;

SELECT 
    'RESUMO' as tipo,
    ns.nota,
    ns.text_prioridade,
    ns.centro_trabalho_responsavel,
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL THEN 'inicio_desejado'
        WHEN ns.criado_em IS NOT NULL THEN 'criacao'
        ELSE 'SEM DATA'
    END as data_referencia_nota,
    CASE 
        WHEN ct.id IS NOT NULL THEN 'CENTRO ENCONTRADO'
        ELSE 'CENTRO NÃO ENCONTRADO'
    END as status_centro,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas rpn 
                     WHERE rpn.ativo = true
                       AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
                           UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
                       AND (
                           (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
                           OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
                       )
                       AND NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id))
        THEN 'TEM REGRA SEM SEGMENTOS ✓'
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas rpn 
                     WHERE rpn.ativo = true
                       AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
                           UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
                       AND (
                           (ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado')
                           OR (ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao')
                       )
                       AND EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id))
        THEN 'TEM REGRA COM SEGMENTOS'
        ELSE 'SEM REGRA ✗'
    END as status_regra,
    vw.data_vencimento as data_vencimento_view,
    vw.dias_restantes as dias_restantes_view
FROM notas_sap ns
LEFT JOIN centros_trabalho ct ON (
    UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
    OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
    OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
)
AND ct.ativo = true
LEFT JOIN notas_sap_com_prazo vw ON vw.nota = ns.nota
WHERE ns.nota IN ('11501274', '11500517')
ORDER BY ns.nota;
