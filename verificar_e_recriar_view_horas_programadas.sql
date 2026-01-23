-- ============================================
-- VERIFICAR E RECRIAR VIEW DE HORAS PROGRAMADAS
-- ============================================
-- Este script verifica se os períodos foram criados e recria a VIEW se necessário
-- IMPORTANTE: Execute todas as consultas para ver o debug completo de cada etapa

-- ============================================
-- 1. VERIFICAR SE OS PERÍODOS FORAM CRIADOS
-- ============================================
SELECT 
  '1. PERÍODOS CRIADOS PARA MATRÍCULA 264259' AS secao,
  COUNT(*) AS total_periodos,
  COUNT(DISTINCT ep.task_id) AS total_tarefas,
  MIN(ep.data_inicio) AS primeiro_periodo,
  MAX(ep.data_fim) AS ultimo_periodo
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
WHERE e.matricula = '264259';

-- Detalhes dos períodos
SELECT 
  '1.1. DETALHES DOS PERÍODOS' AS secao,
  ep.id AS periodo_id,
  ep.executor_id,
  e.matricula,
  e.nome,
  ep.task_id,
  t.tarefa,
  ep.data_inicio,
  ep.data_fim,
  ep.tipo,
  ep.label,
  (ep.data_fim::date - ep.data_inicio::date + 1) AS dias_periodo,
  ((ep.data_fim::date - ep.data_inicio::date + 1) * 8.0) AS horas_periodo
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE e.matricula = '264259'
ORDER BY ep.data_inicio;

-- ============================================
-- 2. VERIFICAR SE A VIEW ESTÁ RETORNANDO DADOS
-- ============================================
SELECT 
  '2. RESULTADO DA VIEW (ANTES DE RECRIAR)' AS secao,
  COUNT(*) AS total_registros
FROM horas_programadas_por_empregado_mes
WHERE matricula = '264259';

-- Detalhes dos registros
SELECT 
  '2.1. DETALHES DA VIEW (ANTES DE RECRIAR)' AS secao,
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

-- ============================================
-- 3. RECRIAR A VIEW
-- ============================================
-- IMPORTANTE: Execute esta seção para recriar a VIEW
-- Isso garante que a VIEW está usando os dados mais recentes

DROP VIEW IF EXISTS horas_programadas_por_empregado_mes;

CREATE VIEW horas_programadas_por_empregado_mes AS
WITH periodos_expandidos AS (
  -- PRINCIPAL: Expandir cada período de executor_periods em meses que ele intersecta
  -- Cada linha de executor_periods representa um período de trabalho de um executor em uma tarefa
  -- JOIN com tasks para incluir informações de regional, divisão e segmento da TAREFA
  -- JOIN com executores para obter a matrícula do executor
  SELECT 
    ep.executor_id,                    -- ID do executor que está trabalhando na tarefa
    COALESCE(e.matricula, '') AS matricula,  -- Matrícula do executor (usado para agrupar)
    ep.task_id,                         -- ID da tarefa (para referência)
    t.regional_id,                      -- Regional da tarefa (para filtro de perfil)
    t.divisao_id,                       -- Divisão da tarefa (para filtro de perfil)
    t.segmento_id,                      -- Segmento da tarefa (para filtro de perfil)
    DATE_TRUNC('month', mes_intersecao)::date AS mes_referencia,
    EXTRACT(YEAR FROM DATE_TRUNC('month', mes_intersecao))::int AS ano,
    EXTRACT(MONTH FROM DATE_TRUNC('month', mes_intersecao))::int AS mes,
    ep.data_inicio,                     -- Data de início do período de trabalho
    ep.data_fim,                        -- Data de fim do período de trabalho
    ep.tipo                             -- Tipo do período (BEA, COMP, TRN, etc. - exclui FER)
  FROM executor_periods ep               -- TABELA PRINCIPAL: períodos de trabalho dos executores nas tarefas
  -- IMPORTANTE: INNER JOIN garante que só pegamos períodos de tarefas que existem
  -- Se uma tarefa não existir, o período não será incluído
  INNER JOIN tasks t ON t.id = ep.task_id  -- JOIN com tasks para obter regional/divisão/segmento da TAREFA
  LEFT JOIN executores e ON e.id = ep.executor_id  -- JOIN com executores para obter matrícula do executor
  CROSS JOIN LATERAL generate_series(
    DATE_TRUNC('month', GREATEST(ep.data_inicio, DATE_TRUNC('year', ep.data_inicio)::date))::date,
    DATE_TRUNC('month', ep.data_fim)::date,
    '1 month'::interval
  ) AS mes_intersecao
  WHERE 
    -- Excluir apenas FÉRIAS (tipo = 'FER')
    (ep.tipo IS NULL OR ep.tipo != 'FER')
    -- Apenas executores com matrícula (mas não filtrar por ativo, regional, divisão ou segmento)
    -- IMPORTANTE: NÃO filtra por regional/divisão/segmento aqui - pega TODOS os executores de TODAS as tarefas
    AND COALESCE(e.matricula, '') != ''
),
dias_uteis_por_periodo AS (
  -- Calcular dias úteis para cada período dentro de cada mês
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
    -- Calcular interseção do período com o mês
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
  -- Calcular TODOS os dias do período (incluindo sábados, domingos e feriados)
  -- IMPORTANTE: Atividades PODEM ser programadas em finais de semana e feriados
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
    -- Contar TODOS os dias do período (incluindo sábados, domingos e feriados)
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
-- RESULTADO FINAL: Agrupa as horas programadas por matrícula, mês/ano e regional/divisão/segmento
-- PRINCIPAL: Cada linha representa as horas programadas de um executor em um mês específico
-- baseado nos períodos de trabalho dele nas TAREFAS (executor_periods)
-- 
-- IMPORTANTE: A VIEW retorna TODOS os executores de TODAS as tarefas, INDEPENDENTE de regional/divisão/segmento
-- O filtro por perfil (regional/divisão/segmento) é aplicado no front-end usando os campos regional_id, divisao_id, segmento_id
SELECT 
  dup.matricula,                        -- Matrícula do executor
  dup.ano,                              -- Ano de referência
  dup.mes,                              -- Mês de referência
  TO_CHAR(dup.mes_referencia, 'YYYY-MM') AS ano_mes,  -- Ano-mês formatado
  -- Incluir IDs de regional, divisão e segmento da TAREFA para filtro no front-end
  dup.regional_id,                      -- Regional da tarefa (para filtro de perfil)
  dup.divisao_id,                       -- Divisão da tarefa (para filtro de perfil)
  dup.segmento_id,                      -- Segmento da tarefa (para filtro de perfil)
  -- PRINCIPAL: Soma os dias de todos os períodos das TAREFAS e multiplica por 8 horas
  -- Cada período de executor_periods (período de trabalho em uma tarefa) contribui com seus dias * 8 horas
  -- IMPORTANTE: Inclui sábados, domingos e feriados, pois atividades podem ser programadas nesses dias
  SUM(COALESCE(dc.dias_trabalhados, 0) * 8.0) AS horas_programadas
FROM dias_uteis_por_periodo dup
LEFT JOIN dias_calculados dc ON 
  dc.executor_id = dup.executor_id
  AND dc.task_id = dup.task_id          -- Garantir que estamos juntando períodos da mesma TAREFA
  AND dc.ano = dup.ano
  AND dc.mes = dup.mes
  AND dc.inicio_intersecao = dup.inicio_intersecao
  AND dc.fim_intersecao = dup.fim_intersecao
WHERE COALESCE(dc.dias_trabalhados, 0) > 0   -- Apenas períodos com dias > 0
GROUP BY 
  dup.matricula,                        -- Agrupar por matrícula do executor
  dup.ano,                              -- Agrupar por ano
  dup.mes,                              -- Agrupar por mês
  dup.mes_referencia,                   -- Agrupar por mês de referência
  dup.regional_id,                      -- Agrupar por regional da TAREFA
  dup.divisao_id,                       -- Agrupar por divisão da TAREFA
  dup.segmento_id                       -- Agrupar por segmento da TAREFA
ORDER BY 
  dup.matricula,
  dup.ano,
  dup.mes;

-- ============================================
-- 4. VERIFICAR SE A VIEW ESTÁ RETORNANDO DADOS APÓS RECRIAR
-- ============================================
SELECT 
  '4. RESULTADO DA VIEW (APÓS RECRIAR)' AS secao,
  COUNT(*) AS total_registros,
  SUM(horas_programadas) AS total_horas,
  MIN(ano_mes) AS primeiro_mes,
  MAX(ano_mes) AS ultimo_mes
FROM horas_programadas_por_empregado_mes
WHERE matricula = '264259';

-- Detalhes dos registros
SELECT 
  '4.1. DETALHES DA VIEW (APÓS RECRIAR)' AS secao,
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

-- ============================================
-- 5. DIAGNÓSTICO: VERIFICAR SE HÁ PROBLEMA COM O JOIN
-- ============================================
-- Resumo do diagnóstico
SELECT 
  '5. DIAGNÓSTICO: RESUMO' AS secao,
  COUNT(*) AS total_periodos,
  COUNT(t.id) AS periodos_com_tarefa,
  COUNT(*) FILTER (WHERE t.id IS NULL) AS periodos_sem_tarefa,
  COUNT(*) FILTER (WHERE t.id IS NOT NULL AND t.regional_id IS NULL AND t.divisao_id IS NULL AND t.segmento_id IS NULL) AS tarefas_sem_regional_divisao_segmento,
  COUNT(*) FILTER (WHERE t.id IS NOT NULL AND (t.regional_id IS NOT NULL OR t.divisao_id IS NOT NULL OR t.segmento_id IS NOT NULL)) AS tarefas_com_regional_divisao_segmento
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE e.matricula = '264259';

-- Detalhes dos períodos e tarefas
SELECT 
  '5.1. DETALHES: PERÍODOS E TAREFAS' AS secao,
  ep.id AS periodo_id,
  ep.executor_id,
  e.matricula,
  ep.task_id,
  t.id AS task_existe,
  t.tarefa,
  t.regional_id,
  t.divisao_id,
  t.segmento_id,
  CASE 
    WHEN t.id IS NULL THEN '❌ TAREFA NÃO EXISTE'
    WHEN t.regional_id IS NULL AND t.divisao_id IS NULL AND t.segmento_id IS NULL THEN '⚠️ TAREFA SEM REGIONAL/DIVISÃO/SEGMENTO'
    ELSE '✅ OK'
  END AS status
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE e.matricula = '264259'
ORDER BY ep.data_inicio;

-- ============================================
-- 6. DIAGNÓSTICO: VERIFICAR O INNER JOIN COM TASKS
-- ============================================
-- Este é o problema mais provável - o INNER JOIN com tasks está excluindo os períodos
SELECT 
  '6. DIAGNÓSTICO: INNER JOIN COM TASKS' AS secao,
  'PERÍODOS SEM TAREFA (SERÃO EXCLUÍDOS PELO INNER JOIN)' AS tipo,
  COUNT(*) AS total
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
  e.matricula = '264259'
  AND t.id IS NULL
UNION ALL
SELECT 
  '6. DIAGNÓSTICO: INNER JOIN COM TASKS' AS secao,
  'PERÍODOS COM TAREFA (PASSARÃO PELO INNER JOIN)' AS tipo,
  COUNT(*) AS total
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
INNER JOIN tasks t ON t.id = ep.task_id
WHERE e.matricula = '264259';

-- Detalhes dos períodos que serão excluídos
SELECT 
  '6.1. PERÍODOS QUE SERÃO EXCLUÍDOS (TAREFA NÃO EXISTE)' AS secao,
  ep.id AS periodo_id,
  ep.executor_id,
  e.matricula,
  ep.task_id,
  'TAREFA NÃO EXISTE' AS problema
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
  e.matricula = '264259'
  AND t.id IS NULL;

-- Detalhes dos períodos que passarão pelo INNER JOIN
SELECT 
  '6.2. PERÍODOS QUE PASSARÃO PELO INNER JOIN' AS secao,
  ep.id AS periodo_id,
  ep.executor_id,
  e.matricula,
  ep.task_id,
  t.id AS task_id_confirmado,
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
-- 7. TESTAR A VIEW PASSO A PASSO
-- ============================================
-- Testar a primeira CTE (periodos_expandidos)
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
  '7. TESTE: PERÍODOS EXPANDIDOS' AS secao,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT matricula) AS executores_unicos,
  COUNT(DISTINCT task_id) AS tarefas_unicas,
  MIN(ano) AS primeiro_ano,
  MAX(ano) AS ultimo_ano
FROM periodos_expandidos
WHERE matricula = '264259';

-- Detalhes dos períodos expandidos
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
  '7.1. DETALHES: PERÍODOS EXPANDIDOS' AS secao,
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
-- 8. TESTAR A SEGUNDA CTE (dias_uteis_por_periodo)
-- ============================================
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
  '8. TESTE: DIAS ÚTEIS POR PERÍODO' AS secao,
  COUNT(*) AS total_registros,
  COUNT(DISTINCT matricula) AS executores_unicos,
  COUNT(DISTINCT task_id) AS tarefas_unicas,
  MIN(ano) AS primeiro_ano,
  MAX(ano) AS ultimo_ano
FROM dias_uteis_por_periodo
WHERE matricula = '264259';

-- Detalhes dos dias úteis por período
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
  '8.1. DETALHES: DIAS ÚTEIS POR PERÍODO' AS secao,
  matricula,
  ano,
  mes,
  mes_referencia,
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
-- 9. TESTAR A TERCEIRA CTE (dias_calculados)
-- ============================================
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
  '9. TESTE: DIAS CALCULADOS' AS secao,
  COUNT(*) AS total_registros,
  SUM(dias_trabalhados) AS total_dias,
  SUM(dias_trabalhados * 8.0) AS total_horas,
  MIN(ano) AS primeiro_ano,
  MAX(ano) AS ultimo_ano
FROM dias_calculados
WHERE matricula = '264259';

-- Detalhes dos dias calculados
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
  '9.1. DETALHES: DIAS CALCULADOS' AS secao,
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
-- 10. TESTAR O RESULTADO FINAL (ANTES DO WHERE)
-- ============================================
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
  '10. TESTE: RESULTADO FINAL (ANTES DO WHERE)' AS secao,
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
