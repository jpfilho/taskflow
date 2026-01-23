-- Script de diagnóstico completo para todas as prioridades

-- 1. Verificar TODAS as regras cadastradas e seus segmentos
SELECT 
    rpn.id as regra_id,
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
ORDER BY rpn.prioridade, rpn.data_referencia;

-- 2. Verificar notas por prioridade e se têm data de referência
SELECT 
    text_prioridade,
    UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as prioridade_normalizada,
    COUNT(*) as total_notas,
    COUNT(inicio_desejado) as com_inicio_desejado,
    COUNT(criado_em) as com_criado_em,
    COUNT(CASE WHEN inicio_desejado IS NULL AND criado_em IS NULL THEN 1 END) as sem_data_referencia,
    COUNT(data_vencimento) as com_prazo_calculado,
    COUNT(*) - COUNT(data_vencimento) as sem_prazo_calculado
FROM notas_sap_com_prazo
WHERE text_prioridade IS NOT NULL
  AND TRIM(text_prioridade) != ''
GROUP BY text_prioridade
ORDER BY total_notas DESC;

-- 3. Verificar notas específicas de "Média", "Urgência" e "Alta" que não têm prazo
-- Usar normalização para encontrar todas as variações
SELECT 
    ns.nota,
    ns.text_prioridade,
    UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as prioridade_normalizada,
    ns.centro_trabalho_responsavel,
    ns.inicio_desejado,
    ns.criado_em,
    ns.data_vencimento,
    ns.dias_restantes,
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL THEN 'TEM inicio_desejado'
        WHEN ns.criado_em IS NOT NULL THEN 'TEM criado_em'
        ELSE 'SEM DATA DE REFERENCIA'
    END as tem_data_referencia,
    -- Verificar se há regra correspondente
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
    ) as regras_encontradas,
    -- Verificar se o centro de trabalho tem segmento
    (
        SELECT string_agg(s.segmento, ', ')
        FROM centros_trabalho ct
        INNER JOIN segmentos s ON s.id = ct.segmento_id
        WHERE (
            UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
            OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
            OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
        )
        AND ct.ativo = true
        LIMIT 1
    ) as segmento_do_centro
FROM notas_sap_com_prazo ns
WHERE UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) IN ('MEDIA', 'URGENCIA', 'ALTA')
  AND ns.data_vencimento IS NULL
ORDER BY ns.text_prioridade, ns.nota
LIMIT 20;

-- 4. Testar correspondência detalhada para uma nota específica de "Média"
SELECT 
    ns.nota,
    ns.text_prioridade as prioridade_nota,
    UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as nota_normalizada,
    ns.centro_trabalho_responsavel,
    ns.inicio_desejado,
    ns.criado_em,
    rpn.prioridade as prioridade_regra,
    UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as regra_normalizada,
    CASE 
        WHEN UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
             UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
        THEN 'MATCH ✓'
        ELSE 'NO MATCH ✗'
    END as match_prioridade,
    rpn.data_referencia,
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado' THEN 'MATCH ✓'
        WHEN ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao' THEN 'MATCH ✓'
        ELSE 'NO MATCH ✗'
    END as match_data_referencia,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS'
        ELSE 'SEM SEGMENTOS (DEVERIA APLICAR)'
    END as regra_tem_segmentos,
    -- Verificar se o segmento do centro corresponde
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'REGRA GERAL - DEVERIA APLICAR'
        WHEN EXISTS (
            SELECT 1 
            FROM regras_prazo_notas_segmentos rpns
            INNER JOIN centros_trabalho ct ON ct.segmento_id = rpns.segmento_id
            WHERE rpns.regra_prazo_nota_id = rpn.id
              AND ct.ativo = true
              AND (
                  UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
                  OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
                  OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
              )
        )
        THEN 'SEGMENTO CORRESPONDE ✓'
        ELSE 'SEGMENTO NÃO CORRESPONDE ✗'
    END as status_segmento
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
ORDER BY ns.nota
LIMIT 5;

-- 5. Comparar "Monitoramento" (que funciona) com "Média" (que não funciona)
-- Usar normalização similar à VIEW para encontrar as prioridades
SELECT 
    'Monitoramento' as prioridade_teste,
    COUNT(*) as total_notas,
    COUNT(data_vencimento) as com_prazo,
    COUNT(*) - COUNT(data_vencimento) as sem_prazo,
    COUNT(inicio_desejado) as com_inicio_desejado,
    COUNT(criado_em) as com_criado_em,
    COUNT(CASE WHEN inicio_desejado IS NULL AND criado_em IS NULL THEN 1 END) as sem_data_referencia
FROM notas_sap_com_prazo
WHERE UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MONITORAMENTO'

UNION ALL

SELECT 
    'Média' as prioridade_teste,
    COUNT(*) as total_notas,
    COUNT(data_vencimento) as com_prazo,
    COUNT(*) - COUNT(data_vencimento) as sem_prazo,
    COUNT(inicio_desejado) as com_inicio_desejado,
    COUNT(criado_em) as com_criado_em,
    COUNT(CASE WHEN inicio_desejado IS NULL AND criado_em IS NULL THEN 1 END) as sem_data_referencia
FROM notas_sap_com_prazo
WHERE UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'

UNION ALL

SELECT 
    'Urgência' as prioridade_teste,
    COUNT(*) as total_notas,
    COUNT(data_vencimento) as com_prazo,
    COUNT(*) - COUNT(data_vencimento) as sem_prazo,
    COUNT(inicio_desejado) as com_inicio_desejado,
    COUNT(criado_em) as com_criado_em,
    COUNT(CASE WHEN inicio_desejado IS NULL AND criado_em IS NULL THEN 1 END) as sem_data_referencia
FROM notas_sap_com_prazo
WHERE UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'URGENCIA'

UNION ALL

SELECT 
    'Alta' as prioridade_teste,
    COUNT(*) as total_notas,
    COUNT(data_vencimento) as com_prazo,
    COUNT(*) - COUNT(data_vencimento) as sem_prazo,
    COUNT(inicio_desejado) as com_inicio_desejado,
    COUNT(criado_em) as com_criado_em,
    COUNT(CASE WHEN inicio_desejado IS NULL AND criado_em IS NULL THEN 1 END) as sem_data_referencia
FROM notas_sap_com_prazo
WHERE UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'ALTA'

UNION ALL

SELECT 
    'Por Oportunidade' as prioridade_teste,
    COUNT(*) as total_notas,
    COUNT(data_vencimento) as com_prazo,
    COUNT(*) - COUNT(data_vencimento) as sem_prazo,
    COUNT(inicio_desejado) as com_inicio_desejado,
    COUNT(criado_em) as com_criado_em,
    COUNT(CASE WHEN inicio_desejado IS NULL AND criado_em IS NULL THEN 1 END) as sem_data_referencia
FROM notas_sap_com_prazo
WHERE UPPER(TRIM(TRANSLATE(text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) LIKE '%OPORTUNIDADE%';
