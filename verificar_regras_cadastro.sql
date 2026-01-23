-- Script para verificar quais regras existem no cadastro e quais precisam ser criadas
-- Use este script para entender o que precisa ser criado no cadastro de Regras de Prazo

-- 1. Verificar TODAS as regras cadastradas
SELECT 
    rpn.id,
    rpn.prioridade,
    rpn.dias_prazo,
    rpn.data_referencia,
    rpn.ativo,
    CASE 
        WHEN EXISTS (SELECT 1 FROM regras_prazo_notas_segmentos rpns WHERE rpns.regra_prazo_nota_id = rpn.id)
        THEN 'TEM SEGMENTOS ESPECÍFICOS'
        ELSE 'SEM SEGMENTOS (APLICA A TODOS) ✓'
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

-- 2. Verificar quais prioridades têm regras SEM segmentos (aplicam a todos)
SELECT 
    rpn.prioridade,
    rpn.data_referencia,
    rpn.dias_prazo,
    'TEM REGRA SEM SEGMENTOS ✓' as status
FROM regras_prazo_notas rpn
WHERE rpn.ativo = true
  AND NOT EXISTS (
      SELECT 1 FROM regras_prazo_notas_segmentos rpns
      WHERE rpns.regra_prazo_nota_id = rpn.id
  )
ORDER BY rpn.prioridade, rpn.data_referencia;

-- 3. Verificar quais prioridades têm APENAS regras COM segmentos (não aplicam quando centro não está na tabela)
SELECT DISTINCT
    rpn.prioridade,
    rpn.data_referencia,
    rpn.dias_prazo,
    'TEM APENAS REGRAS COM SEGMENTOS ⚠️' as status,
    (
        SELECT string_agg(DISTINCT s.segmento, ', ')
        FROM regras_prazo_notas_segmentos rpns
        INNER JOIN segmentos s ON s.id = rpns.segmento_id
        WHERE rpns.regra_prazo_nota_id = rpn.id
    ) as segmentos
FROM regras_prazo_notas rpn
WHERE rpn.ativo = true
  AND EXISTS (
      SELECT 1 FROM regras_prazo_notas_segmentos rpns
      WHERE rpns.regra_prazo_nota_id = rpn.id
  )
  AND NOT EXISTS (
      -- Não tem regra sem segmentos para a mesma prioridade e data_referencia
      SELECT 1 FROM regras_prazo_notas rpn2
      WHERE rpn2.ativo = true
        AND UPPER(TRIM(TRANSLATE(rpn2.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) = 
            UPPER(TRIM(TRANSLATE(rpn.prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
        AND rpn2.data_referencia = rpn.data_referencia
        AND NOT EXISTS (
            SELECT 1 FROM regras_prazo_notas_segmentos rpns2
            WHERE rpns2.regra_prazo_nota_id = rpn2.id
        )
  )
ORDER BY rpn.prioridade, rpn.data_referencia;

-- 4. Estatísticas de notas por prioridade e quantas têm prazo calculado
SELECT 
    UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc'))) as prioridade_normalizada,
    COUNT(*) as total_notas,
    COUNT(ns.data_vencimento) as com_prazo_calculado,
    COUNT(*) - COUNT(ns.data_vencimento) as sem_prazo_calculado,
    ROUND(100.0 * COUNT(ns.data_vencimento) / COUNT(*), 2) as percentual_com_prazo
FROM notas_sap_com_prazo ns
WHERE ns.text_prioridade IS NOT NULL
  AND TRIM(ns.text_prioridade) != ''
GROUP BY UPPER(TRIM(TRANSLATE(ns.text_prioridade, 'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÇáéíóúàèìòùâêîôûãõç', 'AEIOUAEIOUAEIOUAOCaeiouaeiouaeiouaoc')))
ORDER BY total_notas DESC;

-- 5. Resumo: O que precisa ser feito
-- Se uma prioridade tem apenas regras com segmentos e muitas notas sem prazo,
-- você precisa criar uma regra sem segmentos no cadastro para essa prioridade
SELECT 
    'RESUMO' as tipo,
    'Para prioridades com muitas notas sem prazo, crie regras SEM segmentos específicos no cadastro de Regras de Prazo' as instrucao
UNION ALL
SELECT 
    'EXEMPLO' as tipo,
    'Se Média tem 9400 notas e 0 com prazo, crie uma regra para Média sem selecionar segmentos específicos' as instrucao;
