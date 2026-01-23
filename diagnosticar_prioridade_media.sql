-- Script de diagnóstico específico para prioridade "Média"

-- 1. Verificar regras para "Média"
SELECT 
    rpn.id,
    rpn.prioridade,
    UPPER(TRIM(rpn.prioridade)) as prioridade_normalizada,
    rpn.dias_prazo,
    rpn.data_referencia,
    rpn.ativo,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS'
        ELSE 'SEM SEGMENTOS (GERAL)'
    END as tipo_regra,
    (
        SELECT string_agg(s.segmento, ', ')
        FROM regras_prazo_notas_segmentos rpns
        INNER JOIN segmentos s ON s.id = rpns.segmento_id
        WHERE rpns.regra_prazo_nota_id = rpn.id
    ) as segmentos
FROM regras_prazo_notas rpn
WHERE rpn.ativo = true
  AND UPPER(TRIM(rpn.prioridade)) LIKE '%MÉDIA%' OR UPPER(TRIM(rpn.prioridade)) LIKE '%MEDIA%'
ORDER BY rpn.prioridade, rpn.data_referencia;

-- 2. Verificar notas com prioridade "Média" (todas as variações)
SELECT 
    nota,
    text_prioridade,
    UPPER(TRIM(text_prioridade)) as prioridade_normalizada,
    centro_trabalho_responsavel,
    criado_em,
    inicio_desejado,
    data_vencimento,
    dias_restantes
FROM notas_sap_com_prazo
WHERE UPPER(TRIM(text_prioridade)) LIKE '%MÉDIA%' 
   OR UPPER(TRIM(text_prioridade)) LIKE '%MEDIA%'
ORDER BY nota
LIMIT 20;

-- 3. Testar correspondência manual entre nota "Média" e regra
SELECT 
    ns.nota,
    ns.text_prioridade as prioridade_nota,
    UPPER(TRIM(ns.text_prioridade)) as nota_norm,
    rpn.prioridade as prioridade_regra,
    UPPER(TRIM(rpn.prioridade)) as regra_norm,
    CASE 
        WHEN UPPER(TRIM(ns.text_prioridade)) = UPPER(TRIM(rpn.prioridade)) THEN 'MATCH ✓'
        ELSE 'NO MATCH ✗'
    END as match,
    ns.inicio_desejado,
    ns.criado_em,
    rpn.data_referencia,
    rpn.ativo,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS'
        ELSE 'SEM SEGMENTOS'
    END as regra_tem_segmentos,
    -- Verificar se o centro de trabalho tem segmento correspondente
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
    ) as segmento_do_centro,
    -- Calcular manualmente o que deveria ser retornado
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado' 
             AND UPPER(TRIM(ns.text_prioridade)) = UPPER(TRIM(rpn.prioridade))
             AND rpn.ativo = true
             AND (
                 NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
                 OR EXISTS (
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
             )
        THEN (ns.inicio_desejado + INTERVAL '1 day' * rpn.dias_prazo)::date
        WHEN ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao'
             AND UPPER(TRIM(ns.text_prioridade)) = UPPER(TRIM(rpn.prioridade))
             AND rpn.ativo = true
             AND (
                 NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
                 OR EXISTS (
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
             )
        THEN (ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date
        ELSE NULL
    END as data_vencimento_calculada_manual
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE (UPPER(TRIM(ns.text_prioridade)) LIKE '%MÉDIA%' OR UPPER(TRIM(ns.text_prioridade)) LIKE '%MEDIA%')
  AND rpn.ativo = true
  AND (UPPER(TRIM(rpn.prioridade)) LIKE '%MÉDIA%' OR UPPER(TRIM(rpn.prioridade)) LIKE '%MEDIA%')
ORDER BY ns.nota, rpn.prioridade
LIMIT 30;

-- 4. Verificar todas as variações de "Média" nas notas
SELECT DISTINCT
    text_prioridade,
    UPPER(TRIM(text_prioridade)) as normalizada,
    COUNT(*) as quantidade
FROM notas_sap
WHERE UPPER(TRIM(text_prioridade)) LIKE '%MÉDIA%' 
   OR UPPER(TRIM(text_prioridade)) LIKE '%MEDIA%'
GROUP BY text_prioridade
ORDER BY quantidade DESC;

-- 5. Verificar todas as variações de "Média" nas regras
SELECT DISTINCT
    prioridade,
    UPPER(TRIM(prioridade)) as normalizada,
    data_referencia,
    ativo,
    COUNT(*) as quantidade
FROM regras_prazo_notas
WHERE UPPER(TRIM(prioridade)) LIKE '%MÉDIA%' 
   OR UPPER(TRIM(prioridade)) LIKE '%MEDIA%'
GROUP BY prioridade, data_referencia, ativo
ORDER BY prioridade, data_referencia;
