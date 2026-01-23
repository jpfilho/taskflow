-- ==========================================
-- DEBUG: Horas Programadas - Janeiro 2026
-- ==========================================
-- Este script ajuda a entender quais tarefas cada executor está programado para executar
-- Execute cada consulta separadamente no SQL Editor do Supabase

-- ==========================================
-- CONSULTA 0: Verificar se existem períodos de executor no banco
-- ==========================================
SELECT 
    COUNT(*) AS total_periodos,
    COUNT(DISTINCT executor_id) AS total_executores,
    COUNT(DISTINCT task_id) AS total_tarefas,
    MIN(data_inicio) AS data_inicio_mais_antiga,
    MAX(data_fim) AS data_fim_mais_recente
FROM executor_periods;

-- ==========================================
-- CONSULTA 0.1: Verificar tipos de períodos existentes
-- ==========================================
SELECT 
    tipo,
    COUNT(*) AS quantidade
FROM executor_periods
GROUP BY tipo
ORDER BY quantidade DESC;

-- ==========================================
-- CONSULTA 0.2: Verificar períodos que intersectam com janeiro de 2026 (SEM filtrar tipo)
-- ==========================================
SELECT 
    ep.id,
    ep.task_id,
    t.tarefa AS nome_tarefa,
    ep.executor_id,
    e.nome AS nome_executor,
    e.matricula,
    ep.tipo,
    ep.data_inicio,
    ep.data_fim
FROM executor_periods ep
LEFT JOIN tasks t ON t.id = ep.task_id
LEFT JOIN executores e ON e.id = ep.executor_id
WHERE 
    -- Filtrar períodos que intersectam com janeiro de 2026
    (ep.data_inicio <= '2026-01-31'::date AND ep.data_fim >= '2026-01-01'::date)
ORDER BY 
    e.nome,
    ep.data_inicio;

-- ==========================================
-- CONSULTA 0.3: Verificar períodos FER e COMP em janeiro de 2026
-- ==========================================
SELECT 
    ep.tipo,
    COUNT(*) AS quantidade,
    COUNT(DISTINCT ep.executor_id) AS executores_afetados
FROM executor_periods ep
WHERE 
    (ep.data_inicio <= '2026-01-31'::date AND ep.data_fim >= '2026-01-01'::date)
    AND ep.tipo IN ('FER', 'COMP')
GROUP BY ep.tipo;

-- ==========================================
-- CONSULTA 1: Lista todos os períodos de executor em janeiro de 2026
-- ==========================================
SELECT 
    ep.id,
    ep.task_id,
    t.tarefa AS nome_tarefa,
    ep.executor_id,
    e.nome AS nome_executor,
    e.matricula,
    ep.tipo,
    ep.data_inicio,
    ep.data_fim,
    -- Calcular dias úteis no período (excluindo fins de semana)
    EXTRACT(EPOCH FROM (ep.data_fim - ep.data_inicio)) / 86400 AS dias_totais,
    -- Contar dias úteis (excluindo sábados e domingos)
    (
        SELECT COUNT(*)::int
        FROM generate_series(
            DATE_TRUNC('day', ep.data_inicio)::date,
            DATE_TRUNC('day', ep.data_fim)::date,
            '1 day'::interval
        ) AS dia
        WHERE EXTRACT(DOW FROM dia) NOT IN (0, 6) -- 0 = domingo, 6 = sábado
    ) AS dias_uteis,
    -- Calcular horas programadas (dias úteis * 8)
    (
        SELECT COUNT(*)::int
        FROM generate_series(
            DATE_TRUNC('day', ep.data_inicio)::date,
            DATE_TRUNC('day', ep.data_fim)::date,
            '1 day'::interval
        ) AS dia
        WHERE EXTRACT(DOW FROM dia) NOT IN (0, 6)
    ) * 8.0 AS horas_programadas
FROM executor_periods ep
INNER JOIN tasks t ON t.id = ep.task_id
INNER JOIN executores e ON e.id = ep.executor_id
WHERE 
    -- Filtrar períodos que intersectam com janeiro de 2026
    (ep.data_inicio <= '2026-01-31'::date AND ep.data_fim >= '2026-01-01'::date)
    -- Excluir FÉRIAS e COMPENSAÇÃO
    AND ep.tipo NOT IN ('FER', 'COMP')
ORDER BY 
    e.nome,
    ep.data_inicio;

-- ==========================================
-- CONSULTA 2: Agrupar por executor e calcular total de horas programadas em janeiro de 2026
-- ==========================================
SELECT 
    e.id AS executor_id,
    e.nome AS nome_executor,
    e.matricula,
    COUNT(DISTINCT ep.task_id) AS total_tarefas,
    COUNT(ep.id) AS total_periodos,
    SUM(
        (
            SELECT COUNT(*)::int
            FROM generate_series(
                GREATEST(DATE_TRUNC('day', ep.data_inicio)::date, '2026-01-01'::date),
                LEAST(DATE_TRUNC('day', ep.data_fim)::date, '2026-01-31'::date),
                '1 day'::interval
            ) AS dia
            WHERE EXTRACT(DOW FROM dia) NOT IN (0, 6)
        ) * 8.0
    ) AS total_horas_programadas_janeiro
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
WHERE 
    -- Filtrar períodos que intersectam com janeiro de 2026
    (ep.data_inicio <= '2026-01-31'::date AND ep.data_fim >= '2026-01-01'::date)
    -- Excluir FÉRIAS e COMPENSAÇÃO
    AND ep.tipo NOT IN ('FER', 'COMP')
GROUP BY 
    e.id,
    e.nome,
    e.matricula
ORDER BY 
    e.nome;

-- ==========================================
-- CONSULTA 3: Detalhamento por tarefa e executor em janeiro de 2026
-- ==========================================
SELECT 
    t.id AS task_id,
    t.tarefa AS nome_tarefa,
    e.id AS executor_id,
    e.nome AS nome_executor,
    e.matricula,
    ep.tipo,
    ep.data_inicio,
    ep.data_fim,
    -- Calcular interseção com janeiro de 2026
    GREATEST(ep.data_inicio, '2026-01-01'::date) AS inicio_intersecao,
    LEAST(ep.data_fim, '2026-01-31'::date) AS fim_intersecao,
    -- Calcular dias úteis na interseção
    (
        SELECT COUNT(*)::int
        FROM generate_series(
            GREATEST(DATE_TRUNC('day', ep.data_inicio)::date, '2026-01-01'::date),
            LEAST(DATE_TRUNC('day', ep.data_fim)::date, '2026-01-31'::date),
            '1 day'::interval
        ) AS dia
        WHERE EXTRACT(DOW FROM dia) NOT IN (0, 6)
    ) AS dias_uteis_janeiro,
    -- Calcular horas programadas em janeiro
    (
        SELECT COUNT(*)::int
        FROM generate_series(
            GREATEST(DATE_TRUNC('day', ep.data_inicio)::date, '2026-01-01'::date),
            LEAST(DATE_TRUNC('day', ep.data_fim)::date, '2026-01-31'::date),
            '1 day'::interval
        ) AS dia
        WHERE EXTRACT(DOW FROM dia) NOT IN (0, 6)
    ) * 8.0 AS horas_programadas_janeiro
FROM executor_periods ep
INNER JOIN tasks t ON t.id = ep.task_id
INNER JOIN executores e ON e.id = ep.executor_id
WHERE 
    -- Filtrar períodos que intersectam com janeiro de 2026
    (ep.data_inicio <= '2026-01-31'::date AND ep.data_fim >= '2026-01-01'::date)
    -- Excluir FÉRIAS e COMPENSAÇÃO
    AND ep.tipo NOT IN ('FER', 'COMP')
ORDER BY 
    e.nome,
    t.tarefa,
    ep.data_inicio;
