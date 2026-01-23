-- ============================================
-- DEBUG SIMPLES: POR QUE A VIEW NÃO RETORNA OS DADOS?
-- ============================================
-- Este script verifica passo a passo por que a VIEW não retorna dados
-- para o executor com matrícula 264259

-- ============================================
-- PASSO 1: VERIFICAR SE OS PERÍODOS EXISTEM E PASSAM PELOS FILTROS BÁSICOS
-- ============================================
SELECT 
  'PASSO 1: PERÍODOS E FILTROS BÁSICOS' AS secao,
  ep.id AS periodo_id,
  ep.executor_id,
  e.matricula,
  e.nome,
  ep.task_id,
  t.id AS task_existe,
  t.tarefa,
  ep.data_inicio,
  ep.data_fim,
  ep.tipo,
  -- Verificar cada filtro da VIEW
  CASE WHEN ep.tipo = 'FER' THEN '❌ EXCLUÍDO (FER)' ELSE '✅ OK' END AS filtro_tipo,
  CASE WHEN COALESCE(e.matricula, '') = '' THEN '❌ EXCLUÍDO (SEM MATRÍCULA)' ELSE '✅ OK' END AS filtro_matricula,
  CASE WHEN t.id IS NULL THEN '❌ EXCLUÍDO (TAREFA NÃO EXISTE)' ELSE '✅ OK' END AS filtro_tarefa,
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
-- PASSO 2: TESTAR O generate_series (EXPANSÃO DE MESES)
-- ============================================
-- Verifica se os períodos estão sendo expandidos corretamente em meses
SELECT 
  'PASSO 2: EXPANSÃO DE MESES' AS secao,
  ep.id AS periodo_id,
  ep.executor_id,
  e.matricula,
  ep.data_inicio,
  ep.data_fim,
  DATE_TRUNC('month', ep.data_inicio)::date AS mes_inicio,
  DATE_TRUNC('month', ep.data_fim)::date AS mes_fim,
  -- Gerar os meses que o período intersecta
  mes_intersecao::date AS mes_intersecao,
  EXTRACT(YEAR FROM mes_intersecao)::int AS ano,
  EXTRACT(MONTH FROM mes_intersecao)::int AS mes
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
CROSS JOIN LATERAL generate_series(
  DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
  DATE_TRUNC('month', ep.data_fim)::date,
  '1 month'::interval
) AS mes_intersecao
WHERE 
  e.matricula = '264259'
  AND (ep.tipo IS NULL OR ep.tipo != 'FER')
  AND COALESCE(e.matricula, '') != ''
ORDER BY ep.data_inicio, mes_intersecao;

-- ============================================
-- PASSO 3: TESTAR O CÁLCULO DE INTERSEÇÃO COM O MÊS
-- ============================================
-- Verifica se a interseção do período com o mês está sendo calculada corretamente
SELECT 
  'PASSO 3: CÁLCULO DE INTERSEÇÃO' AS secao,
  ep.id AS periodo_id,
  e.matricula,
  ep.data_inicio,
  ep.data_fim,
  mes_intersecao::date AS mes_referencia,
  EXTRACT(YEAR FROM mes_intersecao)::int AS ano,
  EXTRACT(MONTH FROM mes_intersecao)::int AS mes,
  -- Calcular interseção
  GREATEST(
    ep.data_inicio,
    DATE_TRUNC('month', mes_intersecao)::date
  ) AS inicio_intersecao,
  LEAST(
    ep.data_fim,
    (DATE_TRUNC('month', mes_intersecao) + INTERVAL '1 month - 1 day')::date
  ) AS fim_intersecao,
  -- Verificar se a interseção é válida
  CASE 
    WHEN GREATEST(ep.data_inicio, DATE_TRUNC('month', mes_intersecao)::date) <= 
         LEAST(ep.data_fim, (DATE_TRUNC('month', mes_intersecao) + INTERVAL '1 month - 1 day')::date)
    THEN '✅ VÁLIDA'
    ELSE '❌ INVÁLIDA (inicio > fim)'
  END AS status_intersecao
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
CROSS JOIN LATERAL generate_series(
  DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
  DATE_TRUNC('month', ep.data_fim)::date,
  '1 month'::interval
) AS mes_intersecao
WHERE 
  e.matricula = '264259'
  AND (ep.tipo IS NULL OR ep.tipo != 'FER')
  AND COALESCE(e.matricula, '') != ''
ORDER BY ep.data_inicio, mes_intersecao;

-- ============================================
-- PASSO 4: TESTAR O CÁLCULO DE DIAS
-- ============================================
-- Verifica se os dias estão sendo calculados corretamente
SELECT 
  'PASSO 4: CÁLCULO DE DIAS' AS secao,
  ep.id AS periodo_id,
  e.matricula,
  mes_intersecao::date AS mes_referencia,
  EXTRACT(YEAR FROM mes_intersecao)::int AS ano,
  EXTRACT(MONTH FROM mes_intersecao)::int AS mes,
  GREATEST(
    ep.data_inicio,
    DATE_TRUNC('month', mes_intersecao)::date
  ) AS inicio_intersecao,
  LEAST(
    ep.data_fim,
    (DATE_TRUNC('month', mes_intersecao) + INTERVAL '1 month - 1 day')::date
  ) AS fim_intersecao,
  COUNT(*) AS dias_trabalhados,
  COUNT(*) * 8.0 AS horas_calculadas,
  -- Verificar se há dias
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ TEM DIAS'
    ELSE '❌ SEM DIAS'
  END AS status_dias
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
CROSS JOIN LATERAL generate_series(
  DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
  DATE_TRUNC('month', ep.data_fim)::date,
  '1 month'::interval
) AS mes_intersecao
CROSS JOIN LATERAL generate_series(
  GREATEST(
    ep.data_inicio,
    DATE_TRUNC('month', mes_intersecao)::date
  )::date,
  LEAST(
    ep.data_fim,
    (DATE_TRUNC('month', mes_intersecao) + INTERVAL '1 month - 1 day')::date
  )::date,
  '1 day'::interval
) AS dia
WHERE 
  e.matricula = '264259'
  AND (ep.tipo IS NULL OR ep.tipo != 'FER')
  AND COALESCE(e.matricula, '') != ''
  AND GREATEST(ep.data_inicio, DATE_TRUNC('month', mes_intersecao)::date) <= 
      LEAST(ep.data_fim, (DATE_TRUNC('month', mes_intersecao) + INTERVAL '1 month - 1 day')::date)
GROUP BY 
  ep.id,
  e.matricula,
  mes_intersecao,
  ep.data_inicio,
  ep.data_fim
HAVING COUNT(*) > 0
ORDER BY ano, mes;

-- ============================================
-- PASSO 5: TESTAR O JOIN COM TASKS
-- ============================================
-- Verifica se o JOIN com tasks está funcionando corretamente
SELECT 
  'PASSO 5: JOIN COM TASKS' AS secao,
  ep.id AS periodo_id,
  ep.executor_id,
  e.matricula,
  ep.task_id,
  t.id AS task_id_join,
  t.tarefa,
  t.regional_id,
  t.divisao_id,
  t.segmento_id,
  CASE 
    WHEN t.id IS NULL THEN '❌ TAREFA NÃO ENCONTRADA'
    WHEN t.regional_id IS NULL AND t.divisao_id IS NULL AND t.segmento_id IS NULL THEN '⚠️ TAREFA SEM REGIONAL/DIVISÃO/SEGMENTO'
    ELSE '✅ OK'
  END AS status_join
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
  e.matricula = '264259'
  AND (ep.tipo IS NULL OR ep.tipo != 'FER')
  AND COALESCE(e.matricula, '') != ''
ORDER BY ep.data_inicio;

-- ============================================
-- PASSO 6: TESTAR A VIEW COMPLETA (SIMULAÇÃO)
-- ============================================
-- Simula a VIEW completa para ver onde os dados estão sendo perdidos
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
  'PASSO 6: RESULTADO FINAL (SIMULAÇÃO DA VIEW)' AS secao,
  dup.matricula,
  dup.ano,
  dup.mes,
  TO_CHAR(dup.mes_referencia, 'YYYY-MM') AS ano_mes,
  dup.regional_id,
  dup.divisao_id,
  dup.segmento_id,
  COALESCE(dc.dias_trabalhados, 0) AS dias_trabalhados,
  COALESCE(dc.dias_trabalhados, 0) * 8.0 AS horas_programadas,
  CASE 
    WHEN COALESCE(dc.dias_trabalhados, 0) > 0 THEN '✅ PASSA NO WHERE'
    ELSE '❌ FILTRADO PELO WHERE (dias = 0)'
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
-- PASSO 7: COMPARAR COM A VIEW REAL
-- ============================================
-- Compara o resultado da simulação com o resultado real da VIEW
SELECT 
  'PASSO 7: COMPARAÇÃO FINAL' AS secao,
  'SIMULAÇÃO' AS origem,
  matricula,
  ano,
  mes,
  ano_mes,
  horas_programadas,
  regional_id,
  divisao_id,
  segmento_id
FROM (
  -- Simulação da VIEW (mesma query do PASSO 6)
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
    dup.matricula,
    dup.ano,
    dup.mes,
    TO_CHAR(dup.mes_referencia, 'YYYY-MM') AS ano_mes,
    SUM(COALESCE(dc.dias_trabalhados, 0) * 8.0) AS horas_programadas,
    dup.regional_id,
    dup.divisao_id,
    dup.segmento_id
  FROM dias_uteis_por_periodo dup
  LEFT JOIN dias_calculados dc ON 
    dc.executor_id = dup.executor_id
    AND dc.task_id = dup.task_id
    AND dc.ano = dup.ano
    AND dc.mes = dup.mes
    AND dc.inicio_intersecao = dup.inicio_intersecao
    AND dc.fim_intersecao = dup.fim_intersecao
  WHERE COALESCE(dc.dias_trabalhados, 0) > 0
  GROUP BY 
    dup.matricula,
    dup.ano,
    dup.mes,
    dup.mes_referencia,
    dup.regional_id,
    dup.divisao_id,
    dup.segmento_id
) AS simulacao
WHERE matricula = '264259'
UNION ALL
SELECT 
  'PASSO 7: COMPARAÇÃO FINAL' AS secao,
  'VIEW REAL' AS origem,
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
ORDER BY origem, ano, mes;
