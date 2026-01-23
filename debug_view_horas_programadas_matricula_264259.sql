-- ============================================
-- DEBUG: POR QUE A VIEW NÃO RETORNA OS DADOS?
-- ============================================
-- Este script verifica por que os períodos aparecem no debug mas não na VIEW
-- para o executor com matrícula 264259

-- ============================================
-- 1. VERIFICAR SE OS PERÍODOS ESTÃO SENDO FILTRADOS PELA VIEW
-- ============================================
-- Verifica se os períodos existem e se passam pelos filtros da VIEW
SELECT 
  '1. PERÍODOS E FILTROS DA VIEW' AS secao,
  ep.id AS periodo_id,
  ep.executor_id,
  e.matricula,
  e.nome,
  ep.task_id,
  t.tarefa,
  ep.data_inicio,
  ep.data_fim,
  ep.tipo,
  -- Verificar filtros da VIEW
  CASE 
    WHEN ep.tipo = 'FER' THEN 'EXCLUÍDO (FER)'
    WHEN COALESCE(e.matricula, '') = '' THEN 'EXCLUÍDO (SEM MATRÍCULA)'
    WHEN NOT EXISTS (SELECT 1 FROM tasks t2 WHERE t2.id = ep.task_id) THEN 'EXCLUÍDO (TAREFA NÃO EXISTE)'
    ELSE 'DEVE APARECER'
  END AS status_filtro_view,
  -- Verificar se a tarefa tem regional/divisão/segmento
  t.regional_id,
  t.divisao_id,
  t.segmento_id
FROM executor_periods ep
LEFT JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE e.matricula = '264259'
ORDER BY ep.data_inicio;

-- ============================================
-- 2. TESTAR A CTE periodos_expandidos DA VIEW
-- ============================================
-- Esta é a primeira CTE da VIEW - verifica se os períodos passam por aqui
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
  '2. PERÍODOS EXPANDIDOS (CTE periodos_expandidos)' AS secao,
  pe.executor_id,
  pe.matricula,
  pe.task_id,
  pe.ano,
  pe.mes,
  pe.mes_referencia,
  pe.data_inicio,
  pe.data_fim,
  pe.tipo,
  pe.regional_id,
  pe.divisao_id,
  pe.segmento_id
FROM periodos_expandidos pe
WHERE pe.matricula = '264259'
ORDER BY pe.ano, pe.mes, pe.data_inicio;

-- ============================================
-- 3. TESTAR A CTE dias_uteis_por_periodo DA VIEW
-- ============================================
-- Esta é a segunda CTE da VIEW - verifica se os períodos passam por aqui
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
  '3. DIAS ÚTEIS POR PERÍODO (CTE dias_uteis_por_periodo)' AS secao,
  dup.executor_id,
  dup.matricula,
  dup.task_id,
  dup.ano,
  dup.mes,
  dup.mes_referencia,
  dup.inicio_intersecao,
  dup.fim_intersecao,
  dup.regional_id,
  dup.divisao_id,
  dup.segmento_id
FROM dias_uteis_por_periodo dup
WHERE dup.matricula = '264259'
ORDER BY dup.ano, dup.mes, dup.inicio_intersecao;

-- ============================================
-- 4. TESTAR A CTE dias_calculados DA VIEW
-- ============================================
-- Esta é a terceira CTE da VIEW - verifica se os dias estão sendo calculados
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
  '4. DIAS CALCULADOS (CTE dias_calculados)' AS secao,
  dc.executor_id,
  dc.matricula,
  dc.task_id,
  dc.ano,
  dc.mes,
  dc.inicio_intersecao,
  dc.fim_intersecao,
  dc.dias_trabalhados,
  dc.dias_trabalhados * 8.0 AS horas_calculadas,
  dc.regional_id,
  dc.divisao_id,
  dc.segmento_id
FROM dias_calculados dc
WHERE dc.matricula = '264259'
ORDER BY dc.ano, dc.mes, dc.inicio_intersecao;

-- ============================================
-- 5. TESTAR O RESULTADO FINAL DA VIEW (SEM O WHERE)
-- ============================================
-- Esta é a consulta final da VIEW - verifica se os dados aparecem antes do WHERE
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
  '5. RESULTADO FINAL (ANTES DO WHERE)' AS secao,
  dup.matricula,
  dup.ano,
  dup.mes,
  TO_CHAR(dup.mes_referencia, 'YYYY-MM') AS ano_mes,
  dup.regional_id,
  dup.divisao_id,
  dup.segmento_id,
  COALESCE(dc.dias_trabalhados, 0) AS dias_trabalhados,
  COALESCE(dc.dias_trabalhados, 0) * 8.0 AS horas_programadas,
  -- Verificar se será filtrado pelo WHERE
  CASE 
    WHEN COALESCE(dc.dias_trabalhados, 0) > 0 THEN 'PASSA NO WHERE'
    ELSE 'FILTRADO PELO WHERE (dias_trabalhados = 0)'
  END AS status_where
FROM dias_uteis_por_periodo dup
LEFT JOIN dias_calculados dc ON 
  dc.executor_id = dup.executor_id
  AND dc.task_id = dup.task_id
  AND dc.ano = dup.ano
  AND dc.mes = dup.mes
  AND dc.inicio_intersecao = dup.inicio_intersecao
  AND dc.fim_intersecao = dup.fim_intersecao
WHERE dup.matricula = '264259'
ORDER BY dup.ano, dup.mes;

-- ============================================
-- 6. COMPARAR COM O RESULTADO DA VIEW
-- ============================================
-- Compara o resultado esperado com o resultado real da VIEW
SELECT 
  '6. COMPARAÇÃO: VIEW vs ESPERADO' AS secao,
  'VIEW' AS origem,
  matricula,
  ano,
  mes,
  ano_mes,
  horas_programadas,
  regional_id,
  divisao_id,
  segmento_id
FROM horas_programadas_por_empregado_mes
WHERE matricula = '264259'
UNION ALL
SELECT 
  '6. COMPARAÇÃO: VIEW vs ESPERADO' AS secao,
  'ESPERADO (do debug)' AS origem,
  '264259' AS matricula,
  2026 AS ano,
  1 AS mes,
  '2026-01' AS ano_mes,
  40.0 AS horas_programadas,  -- Exemplo: ajuste conforme o debug
  NULL AS regional_id,
  NULL AS divisao_id,
  NULL AS segmento_id
ORDER BY origem, ano, mes;
