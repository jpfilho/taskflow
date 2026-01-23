-- Script para testar a VIEW diretamente e ver por que não está funcionando

-- 1. Testar a VIEW para uma nota específica de Média
SELECT 
    nota,
    text_prioridade,
    centro_trabalho_responsavel,
    criado_em,
    inicio_desejado,
    data_vencimento,
    dias_restantes
FROM notas_sap_com_prazo
WHERE nota = '10554269';

-- 2. Verificar se há regra correspondente para essa nota (teste manual)
SELECT 
    ns.nota,
    ns.text_prioridade,
    ns.centro_trabalho_responsavel,
    ns.criado_em,
    rpn.prioridade,
    rpn.data_referencia,
    rpn.dias_prazo,
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'SEM SEGMENTOS'
        ELSE 'TEM SEGMENTOS'
    END as tipo_regra,
    -- Verificar se o centro de trabalho corresponde aos segmentos
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'APLICA A TODOS'
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
    END as status_segmento,
    -- Calcular manualmente
    (ns.criado_em + INTERVAL '1 day' * rpn.dias_prazo)::date as data_vencimento_manual
FROM notas_sap ns
CROSS JOIN regras_prazo_notas rpn
WHERE ns.nota = '10554269'
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND rpn.ativo = true
  AND rpn.data_referencia = 'criacao';

-- 3. Verificar se o centro de trabalho MNSE.MLG está na tabela
SELECT 
    ct.centro_trabalho,
    ct.ativo,
    s.segmento,
    s.id as segmento_id
FROM centros_trabalho ct
INNER JOIN segmentos s ON s.id = ct.segmento_id
WHERE UPPER(TRIM(ct.centro_trabalho)) = 'MNSE.MLG'
   OR 'MNSE.MLG' LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
   OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%MNSE.MLG%';

-- 4. Verificar quais segmentos a regra de Média tem
SELECT 
    rpn.id as regra_id,
    rpn.prioridade,
    rpn.data_referencia,
    s.segmento,
    s.id as segmento_id
FROM regras_prazo_notas rpn
INNER JOIN regras_prazo_notas_segmentos rpns ON rpns.regra_prazo_nota_id = rpn.id
INNER JOIN segmentos s ON s.id = rpns.segmento_id
WHERE rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND rpn.data_referencia = 'criacao';

-- 5. Verificar se há correspondência entre o segmento do centro e o segmento da regra
SELECT 
    'Centro MNSE.MLG' as tipo,
    ct.centro_trabalho,
    s_centro.segmento as segmento_centro,
    s_centro.id as segmento_id_centro
FROM centros_trabalho ct
INNER JOIN segmentos s_centro ON s_centro.id = ct.segmento_id
WHERE UPPER(TRIM(ct.centro_trabalho)) = 'MNSE.MLG'
   OR 'MNSE.MLG' LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
   OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%MNSE.MLG%'

UNION ALL

SELECT 
    'Segmento da regra Média' as tipo,
    NULL::text as centro_trabalho,
    s_regra.segmento as segmento_centro,
    s_regra.id as segmento_id_centro
FROM regras_prazo_notas rpn
INNER JOIN regras_prazo_notas_segmentos rpns ON rpns.regra_prazo_nota_id = rpn.id
INNER JOIN segmentos s_regra ON s_regra.id = rpns.segmento_id
WHERE rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND rpn.data_referencia = 'criacao';
