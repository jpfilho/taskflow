-- Script para testar a VIEW notas_sap_com_prazo
-- Execute este script para verificar se a VIEW está calculando corretamente

-- 1. Verificar se há regras cadastradas
SELECT 
    id,
    prioridade,
    dias_prazo,
    data_referencia,
    ativo,
    (SELECT COUNT(*) FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id) as segmentos_count
FROM regras_prazo_notas rpn
ORDER BY prioridade, data_referencia;

-- 2. Verificar algumas notas com prioridade
SELECT 
    nota,
    text_prioridade,
    criado_em,
    inicio_desejado,
    UPPER(TRIM(text_prioridade)) as prioridade_normalizada
FROM notas_sap
WHERE text_prioridade IS NOT NULL
LIMIT 10;

-- 3. Testar a VIEW diretamente
SELECT 
    nota,
    text_prioridade,
    criado_em,
    inicio_desejado,
    data_vencimento,
    dias_restantes
FROM notas_sap_com_prazo
WHERE text_prioridade IS NOT NULL
LIMIT 10;

-- 4. Verificar se há correspondência entre prioridades
SELECT DISTINCT
    ns.text_prioridade as prioridade_nota,
    rpn.prioridade as prioridade_regra,
    UPPER(TRIM(ns.text_prioridade)) as nota_normalizada,
    UPPER(TRIM(rpn.prioridade)) as regra_normalizada,
    CASE 
        WHEN UPPER(TRIM(ns.text_prioridade)) = UPPER(TRIM(rpn.prioridade)) THEN 'MATCH'
        ELSE 'NO MATCH'
    END as match_status
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE ns.text_prioridade IS NOT NULL
  AND rpn.ativo = true
ORDER BY match_status, prioridade_nota
LIMIT 30;

-- 5. Verificar quais prioridades únicas existem nas notas
SELECT DISTINCT 
    text_prioridade,
    UPPER(TRIM(text_prioridade)) as normalizada,
    COUNT(*) as quantidade
FROM notas_sap
WHERE text_prioridade IS NOT NULL
GROUP BY text_prioridade
ORDER BY quantidade DESC;

-- 6. Verificar quais prioridades únicas existem nas regras
SELECT DISTINCT 
    prioridade,
    UPPER(TRIM(prioridade)) as normalizada,
    data_referencia,
    ativo,
    COUNT(*) as quantidade
FROM regras_prazo_notas
GROUP BY prioridade, data_referencia, ativo
ORDER BY prioridade, data_referencia;
