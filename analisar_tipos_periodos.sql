-- ==========================================
-- ANÁLISE: Verificar todos os tipos de períodos e suas datas
-- ==========================================
-- Este script ajuda a entender quais tipos de períodos existem e quando

-- 1. Verificar todos os tipos de períodos e suas quantidades
SELECT 
    COALESCE(tipo, 'NULL') AS tipo,
    COUNT(*) AS quantidade,
    COUNT(DISTINCT executor_id) AS executores_unicos,
    MIN(data_inicio) AS data_inicio_mais_antiga,
    MAX(data_fim) AS data_fim_mais_recente
FROM executor_periods
GROUP BY tipo
ORDER BY quantidade DESC;

-- 2. Verificar períodos por mês/ano (todos os tipos)
SELECT 
    DATE_TRUNC('month', data_inicio)::date AS mes_ano,
    COALESCE(tipo, 'NULL') AS tipo,
    COUNT(*) AS quantidade,
    COUNT(DISTINCT executor_id) AS executores_unicos
FROM executor_periods
GROUP BY DATE_TRUNC('month', data_inicio)::date, tipo
ORDER BY mes_ano DESC, quantidade DESC;

-- 3. Verificar períodos em janeiro de 2026 (detalhado)
SELECT 
    ep.id,
    ep.tipo,
    ep.executor_id,
    e.nome AS nome_executor,
    e.matricula,
    ep.data_inicio,
    ep.data_fim,
    t.tarefa AS nome_tarefa,
    -- Verificar se o período está completamente dentro de janeiro
    CASE 
        WHEN ep.data_inicio >= '2026-01-01'::date AND ep.data_fim <= '2026-01-31'::date 
        THEN 'Completo'
        ELSE 'Parcial'
    END AS tipo_intersecao
FROM executor_periods ep
LEFT JOIN executores e ON e.id = ep.executor_id
LEFT JOIN tasks t ON t.id = ep.task_id
WHERE 
    ep.data_inicio <= '2026-01-31'::date 
    AND ep.data_fim >= '2026-01-01'::date
ORDER BY 
    ep.tipo,
    e.nome,
    ep.data_inicio;

-- 4. Verificar se há períodos de outros tipos em outros meses de 2026
SELECT 
    DATE_TRUNC('month', data_inicio)::date AS mes_ano,
    COALESCE(tipo, 'NULL') AS tipo,
    COUNT(*) AS quantidade
FROM executor_periods
WHERE 
    data_inicio >= '2026-01-01'::date 
    AND data_inicio < '2027-01-01'::date
GROUP BY DATE_TRUNC('month', data_inicio)::date, tipo
ORDER BY mes_ano, tipo;

-- 5. Verificar períodos que NÃO são FER ou COMP em 2026
SELECT 
    DATE_TRUNC('month', data_inicio)::date AS mes_ano,
    COALESCE(tipo, 'NULL') AS tipo,
    COUNT(*) AS quantidade,
    COUNT(DISTINCT executor_id) AS executores_unicos
FROM executor_periods
WHERE 
    data_inicio >= '2026-01-01'::date 
    AND data_inicio < '2027-01-01'::date
    AND (tipo IS NULL OR tipo NOT IN ('FER', 'COMP'))
GROUP BY DATE_TRUNC('month', data_inicio)::date, tipo
ORDER BY mes_ano, tipo;
