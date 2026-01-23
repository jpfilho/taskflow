-- ==========================================
-- DEBUG SIMPLES: Verificar dados básicos
-- ==========================================
-- Execute estas consultas primeiro para entender o que está no banco

-- 1. Total de períodos de executor
SELECT 
    COUNT(*) AS total_periodos,
    COUNT(DISTINCT executor_id) AS total_executores,
    COUNT(DISTINCT task_id) AS total_tarefas
FROM executor_periods;

-- 2. Tipos de períodos e suas quantidades
SELECT 
    COALESCE(tipo, 'NULL') AS tipo,
    COUNT(*) AS quantidade
FROM executor_periods
GROUP BY tipo
ORDER BY quantidade DESC;

-- 3. Períodos que intersectam com janeiro de 2026 (TODOS os tipos)
SELECT 
    ep.id,
    ep.tipo,
    ep.executor_id,
    e.nome AS nome_executor,
    e.matricula,
    ep.data_inicio,
    ep.data_fim,
    t.tarefa AS nome_tarefa
FROM executor_periods ep
LEFT JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
    ep.data_inicio <= '2026-01-31'::date 
    AND ep.data_fim >= '2026-01-01'::date
ORDER BY 
    e.nome,
    ep.data_inicio
LIMIT 50;

-- 4. Períodos que intersectam com janeiro de 2026 (EXCLUINDO FER e COMP)
SELECT 
    ep.id,
    ep.tipo,
    ep.executor_id,
    e.nome AS nome_executor,
    e.matricula,
    ep.data_inicio,
    ep.data_fim,
    t.tarefa AS nome_tarefa
FROM executor_periods ep
LEFT JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
    ep.data_inicio <= '2026-01-31'::date 
    AND ep.data_fim >= '2026-01-01'::date
    AND (ep.tipo IS NULL OR ep.tipo NOT IN ('FER', 'COMP'))
ORDER BY 
    e.nome,
    ep.data_inicio
LIMIT 50;

-- 5. Resumo por executor em janeiro de 2026 (TODOS os tipos)
SELECT 
    e.id AS executor_id,
    e.nome AS nome_executor,
    e.matricula,
    COUNT(DISTINCT ep.task_id) AS total_tarefas,
    COUNT(ep.id) AS total_periodos,
    STRING_AGG(DISTINCT ep.tipo::text, ', ') AS tipos_periodos
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
WHERE 
    ep.data_inicio <= '2026-01-31'::date 
    AND ep.data_fim >= '2026-01-01'::date
GROUP BY 
    e.id,
    e.nome,
    e.matricula
ORDER BY 
    e.nome;

-- 6. Resumo por executor em janeiro de 2026 (EXCLUINDO FER e COMP)
SELECT 
    e.id AS executor_id,
    e.nome AS nome_executor,
    e.matricula,
    COUNT(DISTINCT ep.task_id) AS total_tarefas,
    COUNT(ep.id) AS total_periodos,
    STRING_AGG(DISTINCT ep.tipo::text, ', ') AS tipos_periodos
FROM executor_periods ep
INNER JOIN executores e ON e.id = ep.executor_id
WHERE 
    ep.data_inicio <= '2026-01-31'::date 
    AND ep.data_fim >= '2026-01-01'::date
    AND (ep.tipo IS NULL OR ep.tipo NOT IN ('FER', 'COMP'))
GROUP BY 
    e.id,
    e.nome,
    e.matricula
ORDER BY 
    e.nome;
