-- Script para verificar se os centros de trabalho das notas estão na tabela centros_trabalho

-- 1. Verificar se os centros de trabalho das notas de Média estão na tabela centros_trabalho
SELECT DISTINCT
    ns.centro_trabalho_responsavel,
    CASE 
        WHEN ct.id IS NOT NULL THEN 'ENCONTRADO ✓'
        ELSE 'NÃO ENCONTRADO ✗'
    END as status_centro,
    ct.centro_trabalho as centro_trabalho_tabela,
    s.segmento as segmento_do_centro,
    s.id as segmento_id
FROM notas_sap ns
LEFT JOIN centros_trabalho ct ON (
    UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
    OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
    OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
)
AND ct.ativo = true
LEFT JOIN segmentos s ON s.id = ct.segmento_id
WHERE UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND ns.centro_trabalho_responsavel IS NOT NULL
ORDER BY status_centro, ns.centro_trabalho_responsavel
LIMIT 20;

-- 2. Verificar se os segmentos dos centros de trabalho correspondem aos segmentos das regras de Média
SELECT 
    rpn.id as regra_id,
    rpn.prioridade,
    rpn.data_referencia,
    s.segmento as segmento_da_regra,
    s.id as segmento_id,
    COUNT(DISTINCT ct.centro_trabalho) as centros_trabalho_com_este_segmento
FROM regras_prazo_notas rpn
INNER JOIN regras_prazo_notas_segmentos rpns ON rpns.regra_prazo_nota_id = rpn.id
INNER JOIN segmentos s ON s.id = rpns.segmento_id
LEFT JOIN centros_trabalho ct ON ct.segmento_id = s.id AND ct.ativo = true
WHERE rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
GROUP BY rpn.id, rpn.prioridade, rpn.data_referencia, s.segmento, s.id
ORDER BY rpn.id, s.segmento;

-- 3. Testar correspondência específica: nota com centro MNSE.MLG e regra de Média
SELECT 
    'Nota' as tipo,
    ns.nota,
    ns.centro_trabalho_responsavel as centro_nota,
    NULL::text as segmento
FROM notas_sap ns
WHERE ns.nota = '10554269'

UNION ALL

SELECT 
    'Centro na tabela' as tipo,
    NULL::varchar as nota,
    ct.centro_trabalho as centro_nota,
    s.segmento
FROM centros_trabalho ct
INNER JOIN segmentos s ON s.id = ct.segmento_id
WHERE UPPER(TRIM(ct.centro_trabalho)) = 'MNSE.MLG'
   OR 'MNSE.MLG' LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
   OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%MNSE.MLG%'

UNION ALL

SELECT 
    'Segmentos da regra Média' as tipo,
    NULL::varchar as nota,
    NULL::text as centro_nota,
    s.segmento
FROM regras_prazo_notas rpn
INNER JOIN regras_prazo_notas_segmentos rpns ON rpns.regra_prazo_nota_id = rpn.id
INNER JOIN segmentos s ON s.id = rpns.segmento_id
WHERE rpn.ativo = true
  AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND rpn.data_referencia = 'criacao';

-- 4. Verificar quantas notas de Média têm centros de trabalho que correspondem aos segmentos das regras
SELECT 
    COUNT(*) as total_notas_media,
    COUNT(CASE WHEN ct.id IS NOT NULL THEN 1 END) as notas_com_centro_encontrado,
    COUNT(CASE WHEN ct.id IS NULL THEN 1 END) as notas_sem_centro_encontrado,
    COUNT(CASE 
        WHEN ct.id IS NOT NULL 
        AND EXISTS (
            SELECT 1 
            FROM regras_prazo_notas rpn
            INNER JOIN regras_prazo_notas_segmentos rpns ON rpns.regra_prazo_nota_id = rpn.id
            WHERE rpn.ativo = true
              AND UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
              AND rpn.data_referencia = 'criacao'
              AND rpns.segmento_id = ct.segmento_id
        )
        THEN 1 
    END) as notas_com_segmento_correspondente
FROM notas_sap ns
LEFT JOIN centros_trabalho ct ON (
    UPPER(TRIM(ct.centro_trabalho)) = UPPER(TRIM(ns.centro_trabalho_responsavel))
    OR UPPER(TRIM(ns.centro_trabalho_responsavel)) LIKE '%' || UPPER(TRIM(ct.centro_trabalho)) || '%'
    OR UPPER(TRIM(ct.centro_trabalho)) LIKE '%' || UPPER(TRIM(ns.centro_trabalho_responsavel)) || '%'
)
AND ct.ativo = true
WHERE UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 'MEDIA'
  AND ns.centro_trabalho_responsavel IS NOT NULL;
