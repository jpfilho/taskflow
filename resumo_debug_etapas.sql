-- ============================================
-- RESUMO: EXECUTAR TODAS AS ETAPAS DE DEBUG EM ORDEM
-- ============================================
-- Execute este script para ver TODOS os resultados de cada etapa
-- Isso ajuda a identificar exatamente onde os dados estão sendo perdidos
-- 
-- IMPORTANTE: Execute TODAS as consultas em sequência
-- Mesmo que uma etapa retorne 0 ou NULL, execute a próxima
-- Isso mostra exatamente onde os dados estão sendo perdidos

-- ============================================
-- ETAPA 1: PERÍODOS CRIADOS
-- ============================================
SELECT '=== ETAPA 1: PERÍODOS CRIADOS ===' AS etapa;
SELECT 
  '1. RESUMO' AS secao,
  COUNT(*) AS total_periodos,
  COUNT(DISTINCT ep.task_id) AS total_tarefas,
  MIN(ep.data_inicio) AS primeiro_periodo,
  MAX(ep.data_fim) AS ultimo_periodo
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
WHERE e.matricula = '264259';

SELECT 
  '1.1. DETALHES' AS secao,
  ep.id AS periodo_id,
  ep.task_id,
  t.tarefa,
  ep.data_inicio,
  ep.data_fim,
  ep.tipo,
  CASE WHEN t.id IS NULL THEN '❌ TAREFA NÃO EXISTE' ELSE '✅ TAREFA EXISTE' END AS status_tarefa
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE e.matricula = '264259'
ORDER BY ep.data_inicio;

-- ============================================
-- ETAPA 2: DIAGNÓSTICO INNER JOIN COM TASKS
-- ============================================
SELECT '=== ETAPA 2: DIAGNÓSTICO INNER JOIN COM TASKS ===' AS etapa;
-- Resumo do diagnóstico
SELECT 
  '2. RESUMO DO DIAGNÓSTICO' AS secao,
  COUNT(*) FILTER (WHERE t.id IS NULL) AS periodos_sem_tarefa,
  COUNT(*) FILTER (WHERE t.id IS NOT NULL) AS periodos_com_tarefa,
  COUNT(*) AS total_periodos,
  CASE 
    WHEN COUNT(*) FILTER (WHERE t.id IS NULL) = COUNT(*) THEN '❌ TODOS OS PERÍODOS SERÃO EXCLUÍDOS!'
    WHEN COUNT(*) FILTER (WHERE t.id IS NULL) > 0 THEN '⚠️ ALGUNS PERÍODOS SERÃO EXCLUÍDOS'
    ELSE '✅ TODOS OS PERÍODOS PASSARÃO PELO JOIN'
  END AS status
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE e.matricula = '264259';

SELECT 
  '2.1. PERÍODOS QUE SERÃO EXCLUÍDOS' AS secao,
  ep.id AS periodo_id,
  ep.task_id,
  'TAREFA NÃO EXISTE' AS problema
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
  e.matricula = '264259'
  AND t.id IS NULL;

SELECT 
  '2.2. PERÍODOS QUE PASSARÃO PELO JOIN' AS secao,
  ep.id AS periodo_id,
  ep.task_id,
  t.tarefa,
  t.regional_id,
  t.divisao_id,
  t.segmento_id
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
INNER JOIN tasks t ON t.id = ep.task_id
WHERE e.matricula = '264259'
ORDER BY ep.data_inicio;

-- ============================================
-- ETAPA 3: PERÍODOS EXPANDIDOS (PRIMEIRA CTE)
-- ============================================
SELECT '=== ETAPA 3: PERÍODOS EXPANDIDOS (PRIMEIRA CTE) ===' AS etapa;
WITH periodos_expandidos AS (
  SELECT 
    ep.executor_id,
    COALESCE(e.matricula, '') AS matricula,
    ep.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
    ep.data_inicio,
    ep.data_fim,
    ep.tipo
  FROM executor_periods ep
  INNER JOIN tasks t ON t.id = ep.task_id
  LEFT JOIN executores e ON e.id = ep.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE 
    (ep.tipo IS NULL OR ep.tipo != 'FER')
    AND COALESCE(e.matricula, '') != ''
)
SELECT 
  '3. RESUMO' AS secao,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT matricula) AS executores_unicos,
  COUNT(DISTINCT task_id) AS tarefas_unicas,
  MIN(ano) AS primeiro_ano,
  MAX(ano) AS ultimo_ano
FROM periodos_expandidos
WHERE matricula = '264259';

WITH periodos_expandidos AS (
  SELECT 
    ep.executor_id,
    COALESCE(e.matricula, '') AS matricula,
    ep.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
    ep.data_inicio,
    ep.data_fim,
    ep.tipo
  FROM executor_periods ep
  INNER JOIN tasks t ON t.id = ep.task_id
  LEFT JOIN executores e ON e.id = ep.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE 
    (ep.tipo IS NULL OR ep.tipo != 'FER')
    AND COALESCE(e.matricula, '') != ''
)
SELECT 
  '3.1. DETALHES' AS secao,
  matricula,
  ano,
  mes,
  mes_referencia,
  task_id,
  regional_id,
  divisao_id,
  segmento_id,
  data_inicio,
  data_fim,
  tipo
FROM periodos_expandidos
WHERE matricula = '264259'
ORDER BY ano, mes, data_inicio;

-- ============================================
-- ETAPA 4: DIAS ÚTEIS POR PERÍODO (SEGUNDA CTE)
-- ============================================
SELECT '=== ETAPA 4: DIAS ÚTEIS POR PERÍODO (SEGUNDA CTE) ===' AS etapa;
WITH periodos_expandidos AS (
  SELECT 
    ep.executor_id,
    COALESCE(e.matricula, '') AS matricula,
    ep.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
    ep.data_inicio,
    ep.data_fim,
    ep.tipo
  FROM executor_periods ep
  INNER JOIN tasks t ON t.id = ep.task_id
  LEFT JOIN executores e ON e.id = ep.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE 
    (ep.tipo IS NULL OR ep.tipo != 'FER')
    AND COALESCE(e.matricula, '') != ''
),
dias_uteis_por_periodo AS (
  SELECT 
    pe.executor_id,
    pe.matricula,
    pe.task_id,
    pe.regional_id,
    pe.divisao_id,
    pe.segmento_id,
    pe.ano,
    pe.mes,
    pe.mes_referencia,
    pe.data_inicio,
    pe.data_fim,
    pe.tipo,
    GREATEST(
      pe.data_inicio,
      DATE_TRUNC('month', pe.mes_referencia)::date
    ) AS inicio_intersecao,
    LEAST(
      pe.data_fim,
      (DATE_TRUNC('month', pe.mes_referencia) + INTERVAL '1 month - 1 day')::date
    ) AS fim_intersecao
  FROM periodos_expandidos pe
)
SELECT 
  '4. RESUMO' AS secao,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT matricula) AS executores_unicos,
  COUNT(DISTINCT task_id) AS tarefas_unicas,
  MIN(ano) AS primeiro_ano,
  MAX(ano) AS ultimo_ano
FROM dias_uteis_por_periodo
WHERE matricula = '264259';

WITH periodos_expandidos AS (
  SELECT 
    ep.executor_id,
    COALESCE(e.matricula, '') AS matricula,
    ep.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
    ep.data_inicio,
    ep.data_fim,
    ep.tipo
  FROM executor_periods ep
  INNER JOIN tasks t ON t.id = ep.task_id
  LEFT JOIN executores e ON e.id = ep.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE 
    (ep.tipo IS NULL OR ep.tipo != 'FER')
    AND COALESCE(e.matricula, '') != ''
),
dias_uteis_por_periodo AS (
  SELECT 
    pe.executor_id,
    pe.matricula,
    pe.task_id,
    pe.regional_id,
    pe.divisao_id,
    pe.segmento_id,
    pe.ano,
    pe.mes,
    pe.mes_referencia,
    pe.data_inicio,
    pe.data_fim,
    pe.tipo,
    GREATEST(
      pe.data_inicio,
      DATE_TRUNC('month', pe.mes_referencia)::date
    ) AS inicio_intersecao,
    LEAST(
      pe.data_fim,
      (DATE_TRUNC('month', pe.mes_referencia) + INTERVAL '1 month - 1 day')::date
    ) AS fim_intersecao
  FROM periodos_expandidos pe
)
SELECT 
  '4.1. DETALHES' AS secao,
  matricula,
  ano,
  mes,
  task_id,
  inicio_intersecao,
  fim_intersecao,
  (fim_intersecao::date - inicio_intersecao::date + 1) AS dias_calculados,
  CASE 
    WHEN inicio_intersecao <= fim_intersecao THEN '✅ VÁLIDA'
    ELSE '❌ INVÁLIDA (inicio > fim)'
  END AS status_intersecao
FROM dias_uteis_por_periodo
WHERE matricula = '264259'
ORDER BY ano, mes, inicio_intersecao;

-- ============================================
-- ETAPA 5: DIAS CALCULADOS (TERCEIRA CTE)
-- ============================================
SELECT '=== ETAPA 5: DIAS CALCULADOS (TERCEIRA CTE) ===' AS etapa;
WITH periodos_expandidos AS (
  SELECT 
    ep.executor_id,
    COALESCE(e.matricula, '') AS matricula,
    ep.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
    ep.data_inicio,
    ep.data_fim,
    ep.tipo
  FROM executor_periods ep
  INNER JOIN tasks t ON t.id = ep.task_id
  LEFT JOIN executores e ON e.id = ep.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE 
    (ep.tipo IS NULL OR ep.tipo != 'FER')
    AND COALESCE(e.matricula, '') != ''
),
dias_uteis_por_periodo AS (
  SELECT 
    pe.executor_id,
    pe.matricula,
    pe.task_id,
    pe.regional_id,
    pe.divisao_id,
    pe.segmento_id,
    pe.ano,
    pe.mes,
    pe.mes_referencia,
    pe.data_inicio,
    pe.data_fim,
    pe.tipo,
    GREATEST(
      pe.data_inicio,
      DATE_TRUNC('month', pe.mes_referencia)::date
    ) AS inicio_intersecao,
    LEAST(
      pe.data_fim,
      (DATE_TRUNC('month', pe.mes_referencia) + INTERVAL '1 month - 1 day')::date
    ) AS fim_intersecao
  FROM periodos_expandidos pe
),
dias_calculados AS (
  SELECT 
    dup.executor_id,
    dup.matricula,
    dup.task_id,
    dup.regional_id,
    dup.divisao_id,
    dup.segmento_id,
    dup.ano,
    dup.mes,
    dup.inicio_intersecao,
    dup.fim_intersecao,
    COUNT(*) AS dias_trabalhados
  FROM dias_uteis_por_periodo dup
  CROSS JOIN LATERAL generate_series(
    dup.inicio_intersecao::date,
    dup.fim_intersecao::date,
    '1 day'::interval
  ) AS dia
  WHERE dup.inicio_intersecao <= dup.fim_intersecao
  GROUP BY 
    dup.executor_id,
    dup.matricula,
    dup.task_id,
    dup.regional_id,
    dup.divisao_id,
    dup.segmento_id,
    dup.ano,
    dup.mes,
    dup.inicio_intersecao,
    dup.fim_intersecao
)
SELECT 
  '5. RESUMO' AS secao,
  COUNT(*) AS total_registros,
  SUM(dias_trabalhados) AS total_dias,
  SUM(dias_trabalhados * 8.0) AS total_horas,
  MIN(ano) AS primeiro_ano,
  MAX(ano) AS ultimo_ano
FROM dias_calculados
WHERE matricula = '264259';

WITH periodos_expandidos AS (
  SELECT 
    ep.executor_id,
    COALESCE(e.matricula, '') AS matricula,
    ep.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
    ep.data_inicio,
    ep.data_fim,
    ep.tipo
  FROM executor_periods ep
  INNER JOIN tasks t ON t.id = ep.task_id
  LEFT JOIN executores e ON e.id = ep.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE 
    (ep.tipo IS NULL OR ep.tipo != 'FER')
    AND COALESCE(e.matricula, '') != ''
),
dias_uteis_por_periodo AS (
  SELECT 
    pe.executor_id,
    pe.matricula,
    pe.task_id,
    pe.regional_id,
    pe.divisao_id,
    pe.segmento_id,
    pe.ano,
    pe.mes,
    pe.mes_referencia,
    pe.data_inicio,
    pe.data_fim,
    pe.tipo,
    GREATEST(
      pe.data_inicio,
      DATE_TRUNC('month', pe.mes_referencia)::date
    ) AS inicio_intersecao,
    LEAST(
      pe.data_fim,
      (DATE_TRUNC('month', pe.mes_referencia) + INTERVAL '1 month - 1 day')::date
    ) AS fim_intersecao
  FROM periodos_expandidos pe
),
dias_calculados AS (
  SELECT 
    dup.executor_id,
    dup.matricula,
    dup.task_id,
    dup.regional_id,
    dup.divisao_id,
    dup.segmento_id,
    dup.ano,
    dup.mes,
    dup.inicio_intersecao,
    dup.fim_intersecao,
    COUNT(*) AS dias_trabalhados
  FROM dias_uteis_por_periodo dup
  CROSS JOIN LATERAL generate_series(
    dup.inicio_intersecao::date,
    dup.fim_intersecao::date,
    '1 day'::interval
  ) AS dia
  WHERE dup.inicio_intersecao <= dup.fim_intersecao
  GROUP BY 
    dup.executor_id,
    dup.matricula,
    dup.task_id,
    dup.regional_id,
    dup.divisao_id,
    dup.segmento_id,
    dup.ano,
    dup.mes,
    dup.inicio_intersecao,
    dup.fim_intersecao
)
SELECT 
  '5.1. DETALHES' AS secao,
  matricula,
  ano,
  mes,
  task_id,
  inicio_intersecao,
  fim_intersecao,
  dias_trabalhados,
  dias_trabalhados * 8.0 AS horas_calculadas,
  regional_id,
  divisao_id,
  segmento_id
FROM dias_calculados
WHERE matricula = '264259'
ORDER BY ano, mes, inicio_intersecao;

-- ============================================
-- ETAPA 6: RESULTADO FINAL DA VIEW
-- ============================================
SELECT '=== ETAPA 6: RESULTADO FINAL DA VIEW ===' AS etapa;
SELECT 
  '6. RESUMO' AS secao,
  COUNT(*) AS total_registros,
  SUM(horas_programadas) AS total_horas,
  MIN(ano_mes) AS primeiro_mes,
  MAX(ano_mes) AS ultimo_mes
FROM horas_programadas_por_empregado_mes
WHERE matricula = '264259';

SELECT 
  '6.1. DETALHES' AS secao,
  matricula,
  ano,
  mes,
  ano_mes,
  horas_programadas,
  horas_programadas / 8.0 AS dias_programados,
  regional_id,
  divisao_id,
  segmento_id
FROM horas_programadas_por_empregado_mes
WHERE matricula = '264259'
ORDER BY ano, mes;
