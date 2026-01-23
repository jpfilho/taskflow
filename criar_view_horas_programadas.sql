-- ============================================
-- SQL PARA CRIAR VIEW DE HORAS PROGRAMADAS
-- ============================================
-- Esta VIEW calcula as horas programadas por empregado e mês
-- baseado nos períodos de executor (executor_periods)
-- 
-- IMPORTANTE: 
-- - A VIEW NÃO filtra por regional/divisão/segmento - ela pega TODOS os executores de TODAS as tarefas
-- - O filtro por perfil (regional/divisão/segmento) é feito no front-end usando os campos regional_id, divisao_id, segmento_id
-- - Exclui períodos do tipo 'FER' (FÉRIAS)
-- - IMPORTANTE: Atividades PODEM ser programadas em finais de semana e feriados - então conta TODOS os dias do período
-- - Agrupa por matrícula do executor e mês/ano
--
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- ============================================
-- VIEW: horas_programadas_por_empregado_mes
-- ============================================
-- PRINCIPAL: Esta VIEW calcula as horas programadas baseado nas TAREFAS e seus PERÍODOS
-- 
-- FLUXO:
-- 1. Pega os períodos de executor (executor_periods) - que são os períodos de trabalho de cada executor em cada tarefa
-- 2. Faz JOIN com tasks para obter informações da tarefa (regional_id, divisao_id, segmento_id)
-- 3. Faz JOIN com executores para obter a matrícula do executor
-- 4. Expande cada período em meses que ele intersecta
-- 5. Calcula TODOS os dias para cada período dentro de cada mês (incluindo sábados, domingos e feriados)
-- 6. Multiplica dias úteis por 8 horas e agrupa por matrícula e mês/ano
--
-- IMPORTANTE: 
-- - A VIEW pega TODOS os executores de TODAS as tarefas, INDEPENDENTE de regional/divisão/segmento
-- - O filtro por perfil é feito no front-end usando os campos regional_id, divisao_id, segmento_id retornados pela VIEW
-- - Considera apenas períodos que NÃO são FÉRIAS (tipo != 'FER')
-- - Cada período de executor_periods representa um período de trabalho de um executor em uma tarefa
-- - IMPORTANTE: Atividades PODEM ser programadas em finais de semana e feriados - então conta TODOS os dias do período
-- - As horas são calculadas baseado em TODOS os dias do período (incluindo sábados, domingos e feriados)

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
-- COMENTÁRIOS NA VIEW
-- ============================================
COMMENT ON VIEW horas_programadas_por_empregado_mes IS 
'PRINCIPAL: VIEW que calcula horas programadas por empregado e mês baseado nas TAREFAS e seus PERÍODOS (executor_periods). 
Cada período de executor_periods representa um período de trabalho de um executor em uma tarefa.
A VIEW faz JOIN com tasks para obter regional/divisão/segmento e calcula TODOS os dias do período (incluindo sábados, domingos e feriados).
IMPORTANTE: A VIEW retorna TODOS os executores de TODAS as tarefas, INDEPENDENTE de regional/divisão/segmento.
O filtro por perfil é aplicado no front-end usando os campos regional_id, divisao_id, segmento_id.
IMPORTANTE: Atividades PODEM ser programadas em finais de semana e feriados, então conta TODOS os dias.
Exclui períodos de FÉRIAS (tipo = FER).';

-- ============================================
-- TESTE: Verificar horas programadas para janeiro de 2026
-- ============================================
-- Este teste mostra as horas programadas baseadas nos períodos de executor_periods
-- de todas as tarefas para janeiro de 2026
-- SELECT 
--   matricula,
--   ano,
--   mes,
--   ano_mes,
--   horas_programadas
-- FROM horas_programadas_por_empregado_mes
-- WHERE ano = 2026 AND mes = 1
-- ORDER BY matricula;

-- ============================================
-- TESTE: Verificar horas programadas para matrícula 264259
-- ============================================
-- SELECT 
--   matricula,
--   ano,
--   mes,
--   ano_mes,
--   horas_programadas
-- FROM horas_programadas_por_empregado_mes
-- WHERE matricula = '264259'
-- ORDER BY ano, mes;

-- ============================================
-- DIAGNÓSTICO: Verificar quantos períodos de TAREFAS e executores existem
-- ============================================
-- PRINCIPAL: Esta consulta verifica quantos períodos de executor_periods (períodos de trabalho nas TAREFAS) existem
-- Execute esta consulta para verificar quantos períodos existem e quantos executores têm matrícula
-- SELECT 
--   COUNT(*) AS total_periodos,
--   COUNT(DISTINCT ep.executor_id) AS total_executores_distintos,
--   COUNT(DISTINCT e.matricula) FILTER (WHERE e.matricula IS NOT NULL AND e.matricula != '') AS executores_com_matricula,
--   COUNT(*) FILTER (WHERE ep.tipo = 'FER') AS periodos_ferias,
--   COUNT(*) FILTER (WHERE ep.tipo IS NULL OR ep.tipo != 'FER') AS periodos_nao_ferias
-- FROM executor_periods ep
-- LEFT JOIN executores e ON e.id = ep.executor_id
-- WHERE 
--   (ep.data_inicio <= '2026-01-31'::date AND ep.data_fim >= '2026-01-01'::date);

-- ============================================
-- DIAGNÓSTICO: Verificar executores sem matrícula que têm períodos de TAREFAS
-- ============================================
-- PRINCIPAL: Esta consulta verifica executores que têm períodos em executor_periods (períodos de trabalho nas TAREFAS) mas não têm matrícula
-- SELECT 
--   e.id AS executor_id,
--   e.nome,
--   e.matricula,
--   e.ativo,
--   COUNT(ep.id) AS total_periodos
-- FROM executor_periods ep
-- LEFT JOIN executores e ON e.id = ep.executor_id
-- WHERE 
--   (ep.data_inicio <= '2026-01-31'::date AND ep.data_fim >= '2026-01-01'::date)
--   AND (ep.tipo IS NULL OR ep.tipo != 'FER')
--   AND (e.matricula IS NULL OR e.matricula = '')
-- GROUP BY e.id, e.nome, e.matricula, e.ativo
-- ORDER BY total_periodos DESC;
