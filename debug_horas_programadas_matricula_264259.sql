-- ============================================
-- DEBUG: HORAS PROGRAMADAS PARA MATRÍCULA 264259
-- ============================================
-- Este script faz debug completo das horas programadas para o executor com matrícula 264259
-- Mostra todos os períodos, tarefas associadas e cálculo de horas

-- ============================================
-- 0. HORAS PROGRAMADAS DIRETO DA VIEW (RESULTADO FINAL)
-- ============================================
SELECT 
  '0. HORAS PROGRAMADAS DA VIEW' AS secao,
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
ORDER BY 
  ano,
  mes;

-- ============================================
-- 1. VERIFICAR SE O EXECUTOR EXISTE E TEM MATRÍCULA
-- ============================================
SELECT 
  '1. DADOS DO EXECUTOR' AS secao,
  e.id AS executor_id,
  e.nome,
  e.nome_completo,
  e.matricula,
  e.ativo,
  e.empresa_id
FROM executores e
WHERE e.matricula = '264259';

-- ============================================
-- 2. DIAGNÓSTICO: VERIFICAR SE HÁ PERÍODOS CADASTRADOS
-- ============================================
SELECT 
  '2. DIAGNÓSTICO: PERÍODOS CADASTRADOS' AS secao,
  e.id AS executor_id,
  e.matricula,
  e.nome,
  COUNT(ep.id) AS total_periodos,
  COUNT(ep.id) FILTER (WHERE ep.tipo = 'FER') AS periodos_ferias,
  COUNT(ep.id) FILTER (WHERE ep.tipo != 'FER' OR ep.tipo IS NULL) AS periodos_nao_ferias,
  MIN(ep.data_inicio) AS primeiro_periodo,
  MAX(ep.data_fim) AS ultimo_periodo
FROM executores e
LEFT JOIN executor_periods ep ON ep.executor_id = e.id
WHERE e.matricula = '264259'
GROUP BY e.id, e.matricula, e.nome;

-- ============================================
-- 2.1. TAREFAS PROGRAMADAS E SEUS PERÍODOS
-- ============================================
-- PRINCIPAL: Mostra todas as tarefas que o executor está programado e os períodos de cada uma
SELECT 
  '2.1. TAREFAS PROGRAMADAS E PERÍODOS' AS secao,
  t.id AS task_id,
  t.tarefa,
  t.regional_id,
  r.regional,
  t.divisao_id,
  d.divisao,
  t.segmento_id,
  s.segmento,
  t.data_inicio AS tarefa_data_inicio,
  t.data_fim AS tarefa_data_fim,
  -- Dados do período
  ep.id AS periodo_id,
  ep.data_inicio AS periodo_data_inicio,
  ep.data_fim AS periodo_data_fim,
  ep.tipo AS periodo_tipo,
  ep.tipo_periodo,
  ep.label AS periodo_label,
  -- Calcular duração do período em dias
  (ep.data_fim::date - ep.data_inicio::date + 1) AS dias_periodo,
  -- Calcular horas do período (dias * 8)
  ((ep.data_fim::date - ep.data_inicio::date + 1) * 8.0) AS horas_periodo,
  -- Verificar se é FÉRIAS (deve ser excluído)
  CASE 
    WHEN ep.tipo = 'FER' THEN 'SIM (EXCLUÍDO)'
    ELSE 'NÃO'
  END AS eh_ferias
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
INNER JOIN tasks t ON t.id = ep.task_id
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos s ON s.id = t.segmento_id
WHERE e.matricula = '264259'
ORDER BY 
  ep.data_inicio,
  t.tarefa;

-- ============================================
-- 2.2. VERIFICAR TAREFAS ONDE O EXECUTOR ESTÁ ATRIBUÍDO MAS NÃO TEM PERÍODOS
-- ============================================
-- Verifica se o executor está atribuído a tarefas mas não tem períodos cadastrados
SELECT 
  '2.2. TAREFAS SEM PERÍODOS (PROBLEMA!)' AS secao,
  t.id AS task_id,
  t.tarefa,
  t.data_inicio,
  t.data_fim,
  r.regional,
  d.divisao,
  s.segmento,
  'EXECUTOR ESTÁ NA TAREFA MAS NÃO TEM PERÍODOS!' AS problema
FROM tasks t
INNER JOIN tasks_executores te ON te.task_id = t.id
INNER JOIN executores e ON e.id = te.executor_id
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos s ON s.id = t.segmento_id
WHERE 
  e.matricula = '264259'
  AND NOT EXISTS (
    SELECT 1 
    FROM executor_periods ep 
    WHERE ep.task_id = t.id 
    AND ep.executor_id = e.id
  )
ORDER BY t.data_inicio;

-- ============================================
-- 2.3. SCRIPT PARA CRIAR PERÍODOS AUTOMATICAMENTE (SE NECESSÁRIO)
-- ============================================
-- Esta consulta gera um script SQL para criar períodos baseado nas tarefas sem períodos
-- IMPORTANTE: Execute este script apenas se quiser criar períodos automaticamente
-- 
-- SELECT 
--   '2.3. SCRIPT PARA CRIAR PERÍODOS' AS secao,
--   'INSERT INTO executor_periods (task_id, executor_id, executor_nome, data_inicio, data_fim, tipo, tipo_periodo, label) VALUES (' ||
--   '''' || t.id || ''', ' ||
--   '''' || e.id || ''', ' ||
--   '''' || e.nome || ''', ' ||
--   '''' || t.data_inicio::date || ''', ' ||
--   '''' || t.data_fim::date || ''', ' ||
--   '''BEA'', ' ||
--   '''EXECUCAO'', ' ||
--   '''Período automático gerado por script'')' AS script_insert
-- FROM tasks t
-- INNER JOIN tasks_executores te ON te.task_id = t.id
-- INNER JOIN executores e ON e.id = te.executor_id
-- WHERE 
--   e.matricula = '264259'
--   AND NOT EXISTS (
--     SELECT 1 
--     FROM executor_periods ep 
--     WHERE ep.task_id = t.id 
--     AND ep.executor_id = e.id
--   );

-- ============================================
-- 4. PERÍODOS EXPANDIDOS POR MÊS (SIMULANDO A VIEW)
-- ============================================
SELECT 
  '4. PERÍODOS EXPANDIDOS POR MÊS' AS secao,
  ep.executor_id,
  e.matricula,
  ep.task_id,
  t.tarefa,
  t.regional_id,
  t.divisao_id,
  t.segmento_id,
  DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
  EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
  EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
  ep.data_inicio,
  ep.data_fim,
  ep.tipo,
  -- Calcular interseção do período com o mês
  GREATEST(
    ep.data_inicio,
    DATE_TRUNC('month', mes_intersecao)::date
  ) AS inicio_intersecao,
  LEAST(
    ep.data_fim,
    (DATE_TRUNC('month', mes_intersecao) + INTERVAL '1 month - 1 day')::date
  ) AS fim_intersecao
FROM executor_periods ep
INNER JOIN tasks t ON t.id = ep.task_id
INNER JOIN executores e ON e.id = ep.executor_id
CROSS JOIN LATERAL generate_series(
  DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
  DATE_TRUNC('month', ep.data_fim)::date,
  '1 month'::interval
) AS mes_intersecao
WHERE 
  e.matricula = '264259'
  AND (ep.tipo IS NULL OR ep.tipo != 'FER')
ORDER BY 
  mes_referencia,
  ep.data_inicio;

-- ============================================
-- 5. CÁLCULO DE DIAS POR PERÍODO E MÊS
-- ============================================
WITH periodos_expandidos AS (
  SELECT 
    ep.executor_id,
    e.matricula,
    ep.task_id,
    t.regional_id,
    t.divisao_id,
    t.segmento_id,
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
    ep.data_inicio,
    ep.data_fim,
    ep.tipo,
    GREATEST(
      ep.data_inicio,
      DATE_TRUNC('month', mes_intersecao)::date
    ) AS inicio_intersecao,
    LEAST(
      ep.data_fim,
      (DATE_TRUNC('month', mes_intersecao) + INTERVAL '1 month - 1 day')::date
    ) AS fim_intersecao
  FROM executor_periods ep
  INNER JOIN tasks t ON t.id = ep.task_id
  INNER JOIN executores e ON e.id = ep.executor_id
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE 
    e.matricula = '264259'
    AND (ep.tipo IS NULL OR ep.tipo != 'FER')
),
dias_calculados AS (
  SELECT 
    pe.executor_id,
    pe.matricula,
    pe.task_id,
    pe.regional_id,
    pe.divisao_id,
    pe.segmento_id,
    pe.ano,
    pe.mes,
    pe.inicio_intersecao,
    pe.fim_intersecao,
    COUNT(*) AS dias_trabalhados
  FROM periodos_expandidos pe
  CROSS JOIN LATERAL generate_series(
    pe.inicio_intersecao::date,
    pe.fim_intersecao::date,
    '1 day'::interval
  ) AS dia
  WHERE pe.inicio_intersecao <= pe.fim_intersecao
  GROUP BY 
    pe.executor_id,
    pe.matricula,
    pe.task_id,
    pe.regional_id,
    pe.divisao_id,
    pe.segmento_id,
    pe.ano,
    pe.mes,
    pe.inicio_intersecao,
    pe.fim_intersecao
)
SELECT 
  '5. CÁLCULO DE DIAS POR PERÍODO' AS secao,
  dc.matricula,
  dc.ano,
  dc.mes,
  TO_CHAR(pe.mes_referencia, 'YYYY-MM') AS ano_mes,
  dc.task_id,
  t.tarefa,
  dc.inicio_intersecao,
  dc.fim_intersecao,
  dc.dias_trabalhados,
  dc.dias_trabalhados * 8.0 AS horas_periodo
FROM dias_calculados dc
INNER JOIN periodos_expandidos pe ON 
  pe.executor_id = dc.executor_id
  AND pe.task_id = dc.task_id
  AND pe.ano = dc.ano
  AND pe.mes = dc.mes
  AND pe.inicio_intersecao = dc.inicio_intersecao
  AND pe.fim_intersecao = dc.fim_intersecao
LEFT JOIN tasks t ON t.id = dc.task_id
ORDER BY 
  dc.ano,
  dc.mes,
  dc.inicio_intersecao;

-- ============================================
-- 6. RESUMO POR MÊS (AGREGADO - TODAS AS TAREFAS)
-- ============================================
SELECT 
  '6. RESUMO POR MÊS (AGREGADO)' AS secao,
  matricula,
  ano,
  mes,
  TO_CHAR(mes_referencia, 'YYYY-MM') AS ano_mes,
  COUNT(DISTINCT task_id) AS total_tarefas,
  SUM(dias_trabalhados) AS total_dias,
  SUM(dias_trabalhados * 8.0) AS total_horas_programadas
FROM (
  WITH periodos_expandidos AS (
    SELECT 
      ep.executor_id,
      e.matricula,
      ep.task_id,
      t.regional_id,
      t.divisao_id,
      t.segmento_id,
      DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
      EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
      EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
      ep.data_inicio,
      ep.data_fim,
      GREATEST(
        ep.data_inicio,
        DATE_TRUNC('month', mes_intersecao)::date
      ) AS inicio_intersecao,
      LEAST(
        ep.data_fim,
        (DATE_TRUNC('month', mes_intersecao) + INTERVAL '1 month - 1 day')::date
      ) AS fim_intersecao
    FROM executor_periods ep
    INNER JOIN tasks t ON t.id = ep.task_id
    INNER JOIN executores e ON e.id = ep.executor_id
    CROSS JOIN LATERAL generate_series(
      DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
      DATE_TRUNC('month', ep.data_fim)::date,
      '1 month'::interval
    ) AS mes_intersecao
    WHERE 
      e.matricula = '264259'
      AND (ep.tipo IS NULL OR ep.tipo != 'FER')
  ),
  dias_calculados AS (
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
      pe.inicio_intersecao,
      pe.fim_intersecao,
      COUNT(*) AS dias_trabalhados
    FROM periodos_expandidos pe
    CROSS JOIN LATERAL generate_series(
      pe.inicio_intersecao::date,
      pe.fim_intersecao::date,
      '1 day'::interval
    ) AS dia
    WHERE pe.inicio_intersecao <= pe.fim_intersecao
    GROUP BY 
      pe.executor_id,
      pe.matricula,
      pe.task_id,
      pe.regional_id,
      pe.divisao_id,
      pe.segmento_id,
      pe.ano,
      pe.mes,
      pe.mes_referencia,
      pe.inicio_intersecao,
      pe.fim_intersecao
  )
  SELECT 
    dc.matricula,
    dc.ano,
    dc.mes,
    pe.mes_referencia,
    dc.task_id,
    dc.dias_trabalhados
  FROM dias_calculados dc
  INNER JOIN periodos_expandidos pe ON 
    pe.executor_id = dc.executor_id
    AND pe.task_id = dc.task_id
    AND pe.ano = dc.ano
    AND pe.mes = dc.mes
    AND pe.inicio_intersecao = dc.inicio_intersecao
    AND pe.fim_intersecao = dc.fim_intersecao
) AS detalhes
GROUP BY 
  matricula,
  ano,
  mes,
  mes_referencia
ORDER BY 
  ano,
  mes;

-- ============================================
-- 7. COMPARAÇÃO COM A VIEW
-- ============================================
SELECT 
  '7. RESULTADO DA VIEW' AS secao,
  matricula,
  ano,
  mes,
  ano_mes,
  regional_id,
  divisao_id,
  segmento_id,
  horas_programadas
FROM horas_programadas_por_empregado_mes
WHERE matricula = '264259'
ORDER BY 
  ano,
  mes;

-- ============================================
-- 8. VERIFICAR PERÍODOS QUE PODEM ESTAR FALTANDO
-- ============================================
SELECT 
  '8. PERÍODOS SEM TAREFA (PROBLEMA!)' AS secao,
  ep.id AS periodo_id,
  ep.task_id,
  ep.executor_id,
  ep.executor_nome,
  ep.data_inicio,
  ep.data_fim,
  ep.tipo,
  CASE 
    WHEN t.id IS NULL THEN 'TAREFA NÃO EXISTE!'
    ELSE 'TAREFA EXISTE'
  END AS status_tarefa
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
  e.matricula = '264259'
  AND (ep.tipo IS NULL OR ep.tipo != 'FER')
  AND t.id IS NULL;

-- ============================================
-- 9. VERIFICAR PERÍODOS DE FÉRIAS (DEVEM SER EXCLUÍDOS)
-- ============================================
SELECT 
  '9. PERÍODOS DE FÉRIAS (EXCLUÍDOS)' AS secao,
  ep.id AS periodo_id,
  ep.task_id,
  ep.executor_id,
  ep.executor_nome,
  ep.data_inicio,
  ep.data_fim,
  ep.tipo,
  t.tarefa
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
  e.matricula = '264259'
  AND ep.tipo = 'FER'
ORDER BY ep.data_inicio;

-- ============================================
-- 10. RESUMO FINAL: TOTAL DE HORAS PROGRAMADAS POR MÊS
-- ============================================
SELECT 
  '10. RESUMO FINAL: TOTAL DE HORAS POR MÊS' AS secao,
  matricula,
  ano,
  mes,
  ano_mes,
  horas_programadas,
  horas_programadas / 8.0 AS dias_programados,
  CASE 
    WHEN mes = 1 THEN 'Janeiro'
    WHEN mes = 2 THEN 'Fevereiro'
    WHEN mes = 3 THEN 'Março'
    WHEN mes = 4 THEN 'Abril'
    WHEN mes = 5 THEN 'Maio'
    WHEN mes = 6 THEN 'Junho'
    WHEN mes = 7 THEN 'Julho'
    WHEN mes = 8 THEN 'Agosto'
    WHEN mes = 9 THEN 'Setembro'
    WHEN mes = 10 THEN 'Outubro'
    WHEN mes = 11 THEN 'Novembro'
    WHEN mes = 12 THEN 'Dezembro'
  END AS nome_mes
FROM horas_programadas_por_empregado_mes
WHERE matricula = '264259'
ORDER BY 
  ano,
  mes;
