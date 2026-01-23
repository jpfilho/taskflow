-- Script para testar a VIEW notas_sap_com_prazo com consideração de segmentos

-- 1. Verificar regras e seus segmentos
SELECT 
    rpn.id as regra_id,
    rpn.prioridade,
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

-- 2. Verificar centros de trabalho e seus segmentos
SELECT 
    ct.centro_trabalho,
    ct.ativo,
    s.segmento,
    s.id as segmento_id
FROM centros_trabalho ct
INNER JOIN segmentos s ON s.id = ct.segmento_id
WHERE ct.ativo = true
ORDER BY ct.centro_trabalho
LIMIT 20;

-- 3. Verificar notas com centro de trabalho e testar correspondência
SELECT 
    ns.nota,
    ns.text_prioridade,
    ns.centro_trabalho_responsavel,
    ns.inicio_desejado,
    ns.criado_em,
    ct.centro_trabalho as centro_trabalho_encontrado,
    s.segmento as segmento_do_centro,
    CASE 
        WHEN ct.id IS NOT NULL THEN 'CENTRO ENCONTRADO'
        ELSE 'CENTRO NÃO ENCONTRADO'
    END as status_centro
FROM notas_sap ns
LEFT JOIN centros_trabalho ct ON (
    UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
    OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
    OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
)
AND ct.ativo = true
LEFT JOIN segmentos s ON s.id = ct.segmento_id
WHERE ns.text_prioridade IS NOT NULL
  AND TRIM(ns.text_prioridade) != ''
LIMIT 20;

-- 4. Testar a VIEW diretamente
SELECT 
    nota,
    text_prioridade,
    centro_trabalho_responsavel,
    criado_em,
    inicio_desejado,
    data_vencimento,
    dias_restantes
FROM notas_sap_com_prazo
WHERE text_prioridade IS NOT NULL
  AND TRIM(text_prioridade) != ''
ORDER BY nota
LIMIT 20;

-- 5. Verificar quantas notas têm prazo calculado vs NULL
SELECT 
    COUNT(*) as total_notas,
    COUNT(data_vencimento) as notas_com_prazo,
    COUNT(*) - COUNT(data_vencimento) as notas_sem_prazo
FROM notas_sap_com_prazo
WHERE text_prioridade IS NOT NULL
  AND TRIM(text_prioridade) != '';
