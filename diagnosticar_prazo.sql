-- Script de diagnóstico detalhado para entender por que a VIEW retorna NULL

-- 1. Verificar regras ativas sem segmentos
SELECT 
    rpn.id,
    rpn.prioridade,
    rpn.dias_prazo,
    rpn.data_referencia,
    rpn.ativo,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS'
        ELSE 'SEM SEGMENTOS (GERAL)'
    END as tipo_regra
FROM regras_prazo_notas rpn
WHERE rpn.ativo = true
ORDER BY rpn.prioridade, rpn.data_referencia;

-- 2. Verificar notas com prioridade e suas datas
SELECT 
    nota,
    text_prioridade,
    UPPER(TRIM(text_prioridade)) as prioridade_normalizada,
    criado_em,
    inicio_desejado,
    CASE 
        WHEN inicio_desejado IS NOT NULL THEN 'TEM inicio_desejado'
        WHEN criado_em IS NOT NULL THEN 'TEM criado_em'
        ELSE 'SEM DATA DE REFERENCIA'
    END as tem_data_referencia
FROM notas_sap
WHERE text_prioridade IS NOT NULL
  AND TRIM(text_prioridade) != ''
LIMIT 20;

-- 3. Testar correspondência manual entre uma nota e uma regra
SELECT 
    ns.nota,
    ns.text_prioridade as prioridade_nota,
    rpn.prioridade as prioridade_regra,
    UPPER(TRIM(ns.text_prioridade)) as nota_norm,
    UPPER(TRIM(rpn.prioridade)) as regra_norm,
    CASE 
        WHEN UPPER(TRIM(ns.text_prioridade)) = UPPER(TRIM(rpn.prioridade)) THEN 'MATCH'
        ELSE 'NO MATCH'
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
    -- Calcular manualmente o que a VIEW deveria retornar
    CASE 
        WHEN ns.inicio_desejado IS NOT NULL AND rpn.data_referencia = 'inicio_desejado' 
             AND UPPER(TRIM(ns.text_prioridade)) = UPPER(TRIM(rpn.prioridade))
             AND rpn.ativo = true
             AND NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN (ns.inicio_desejado + INTERVAL '1 day' * rpn.dias_prazo)::date
        WHEN ns.criado_em IS NOT NULL AND rpn.data_referencia = 'criacao'
             AND UPPER(TRIM(ns.text_prioridade)) = UPPER(TRIM(rpn.prioridade))
             AND rpn.ativo = true
             AND NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN (ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date
        ELSE NULL
    END as data_vencimento_calculada
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE ns.text_prioridade IS NOT NULL
  AND TRIM(ns.text_prioridade) != ''
  AND rpn.ativo = true
ORDER BY ns.nota, rpn.prioridade
LIMIT 30;

-- 4. Testar a VIEW diretamente com uma nota específica
SELECT 
    nota,
    text_prioridade,
    criado_em,
    inicio_desejado,
    data_vencimento,
    dias_restantes
FROM notas_sap_com_prazo
WHERE text_prioridade IS NOT NULL
  AND TRIM(text_prioridade) != ''
ORDER BY nota
LIMIT 20;
