-- ============================================
-- SCRIPT PARA CRIAR PERÍODOS AUTOMATICAMENTE
-- ============================================
-- Este script cria:
-- 1. Segmentos em gantt_segments (se a tarefa não tiver segmentos)
-- 2. Períodos em executor_periods para executores atribuídos sem períodos
--
-- IMPORTANTE: 
-- - TODA TAREFA TEM PERÍODO (data_inicio e data_fim na tabela tasks)
-- - UMA TAREFA PODE TER MAIS DE UM PERÍODO (múltiplos segmentos em gantt_segments)
-- - Este script cria segmentos em gantt_segments baseado nas datas da tarefa
-- - Este script cria períodos em executor_periods baseado nas datas da tarefa
-- - O tipo do período será 'BEA' (trabalho normal)
-- - O tipo_periodo será 'EXECUCAO'
-- - Execute apenas se quiser criar períodos automaticamente
--
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- ============================================
-- 1. VERIFICAR TAREFAS SEM SEGMENTOS E SEM PERÍODOS
-- ============================================
-- Execute esta consulta primeiro para ver quais tarefas serão afetadas
SELECT 
  'TAREFAS QUE TERÃO SEGMENTOS/PERÍODOS CRIADOS' AS secao,
  t.id AS task_id,
  t.tarefa,
  t.data_inicio,
  t.data_fim,
  -- Verificar se tem segmentos em gantt_segments
  CASE 
    WHEN EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id) 
    THEN 'TEM SEGMENTOS'
    ELSE 'SEM SEGMENTOS (SERÁ CRIADO)'
  END AS status_gantt_segments,
  -- Verificar executores sem períodos
  COUNT(DISTINCT e.id) FILTER (
    WHERE NOT EXISTS (
      SELECT 1 
      FROM executor_periods ep 
      WHERE ep.task_id = t.id 
      AND ep.executor_id = e.id
    )
  ) AS executores_sem_periodos,
  (t.data_fim::date - t.data_inicio::date + 1) AS dias_tarefa,
  ((t.data_fim::date - t.data_inicio::date + 1) * 8.0) AS horas_que_serao_criadas
FROM tasks t
LEFT JOIN tasks_executores te ON te.task_id = t.id
LEFT JOIN executores e ON e.id = te.executor_id AND e.matricula = '264259'
WHERE 
  t.data_inicio IS NOT NULL
  AND t.data_fim IS NOT NULL
  AND (
    -- Tarefas sem segmentos em gantt_segments
    NOT EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id)
    OR
    -- Tarefas com executores sem períodos
    (e.id IS NOT NULL AND NOT EXISTS (
      SELECT 1 
      FROM executor_periods ep 
      WHERE ep.task_id = t.id 
      AND ep.executor_id = e.id
    ))
  )
GROUP BY t.id, t.tarefa, t.data_inicio, t.data_fim
ORDER BY t.data_inicio;

-- ============================================
-- 2. CRIAR SEGMENTOS EM GANTT_SEGMENTS
-- ============================================
-- IMPORTANTE: Descomente as linhas abaixo para executar a inserção
-- 
-- Este script cria segmentos em gantt_segments para tarefas que não têm segmentos
-- usando as datas da tarefa (tasks.data_inicio e tasks.data_fim)
--
-- INSERT INTO gantt_segments (
--   task_id,
--   data_inicio,
--   data_fim,
--   label,
--   tipo,
--   tipo_periodo
-- )
-- SELECT 
--   t.id AS task_id,
--   t.data_inicio::date AS data_inicio,  -- Usa a data_inicio da tarefa
--   t.data_fim::date AS data_fim,        -- Usa a data_fim da tarefa
--   t.tarefa AS label,                   -- Usa o nome da tarefa como label
--   'BEA' AS tipo,  -- Tipo padrão: trabalho normal
--   'EXECUCAO' AS tipo_periodo  -- Tipo de período padrão
-- FROM tasks t
-- WHERE 
--   t.data_inicio IS NOT NULL  -- Garante que a tarefa tem data_inicio
--   AND t.data_fim IS NOT NULL      -- Garante que a tarefa tem data_fim
--   AND NOT EXISTS (
--     SELECT 1 
--     FROM gantt_segments gs 
--     WHERE gs.task_id = t.id
--   );

-- ============================================
-- 3. CRIAR PERÍODOS EM EXECUTOR_PERIODS
-- ============================================
-- IMPORTANTE: Descomente as linhas abaixo para executar a inserção
-- 
-- Este script usa as datas da tarefa (tasks.data_inicio e tasks.data_fim)
-- para criar períodos em executor_periods para executores que estão atribuídos
-- mas não têm períodos cadastrados
--
-- INSERT INTO executor_periods (
--   task_id,
--   executor_id,
--   executor_nome,
--   data_inicio,
--   data_fim,
--   tipo,
--   tipo_periodo,
--   label
-- )
-- SELECT 
--   t.id AS task_id,
--   e.id AS executor_id,
--   COALESCE(e.nome_completo, e.nome) AS executor_nome,
--   t.data_inicio::date AS data_inicio,  -- Usa a data_inicio da tarefa
--   t.data_fim::date AS data_fim,        -- Usa a data_fim da tarefa
--   'BEA' AS tipo,  -- Tipo padrão: trabalho normal
--   'EXECUCAO' AS tipo_periodo,
--   'Período automático criado por script' AS label
-- FROM tasks t
-- INNER JOIN tasks_executores te ON te.task_id = t.id
-- INNER JOIN executores e ON e.id = te.executor_id
-- WHERE 
--   e.matricula = '264259'
--   AND t.data_inicio IS NOT NULL  -- Garante que a tarefa tem data_inicio
--   AND t.data_fim IS NOT NULL      -- Garante que a tarefa tem data_fim
--   AND NOT EXISTS (
--     SELECT 1 
--     FROM executor_periods ep 
--     WHERE ep.task_id = t.id 
--     AND ep.executor_id = e.id
--   );

-- ============================================
-- 4. VERIFICAR SEGMENTOS CRIADOS EM GANTT_SEGMENTS
-- ============================================
-- Execute esta consulta após criar os segmentos para verificar
-- SELECT 
--   'SEGMENTOS CRIADOS EM GANTT_SEGMENTS' AS secao,
--   gs.id AS segmento_id,
--   gs.task_id,
--   t.tarefa,
--   gs.data_inicio,
--   gs.data_fim,
--   gs.label,
--   gs.tipo,
--   (gs.data_fim::date - gs.data_inicio::date + 1) AS dias_segmento,
--   ((gs.data_fim::date - gs.data_inicio::date + 1) * 8.0) AS horas_segmento
-- FROM gantt_segments gs
-- INNER JOIN tasks t ON t.id = gs.task_id
-- WHERE 
--   gs.label = t.tarefa  -- Segmentos criados automaticamente terão o mesmo label da tarefa
--   AND NOT EXISTS (
--     SELECT 1 
--     FROM gantt_segments gs2 
--     WHERE gs2.task_id = gs.task_id 
--     AND gs2.id != gs.id
--   )  -- Apenas tarefas com um único segmento (provavelmente criado automaticamente)
-- ORDER BY gs.data_inicio;

-- ============================================
-- 5. VERIFICAR PERÍODOS CRIADOS EM EXECUTOR_PERIODS
-- ============================================
-- Execute esta consulta após criar os períodos para verificar
-- SELECT 
--   'PERÍODOS CRIADOS EM EXECUTOR_PERIODS' AS secao,
--   ep.id AS periodo_id,
--   ep.task_id,
--   t.tarefa,
--   ep.executor_id,
--   e.matricula,
--   ep.executor_nome,
--   ep.data_inicio,
--   ep.data_fim,
--   ep.tipo,
--   ep.tipo_periodo,
--   ep.label,
--   (ep.data_fim::date - ep.data_inicio::date + 1) AS dias_periodo,
--   ((ep.data_fim::date - ep.data_inicio::date + 1) * 8.0) AS horas_periodo
-- FROM executor_periods ep
-- INNER JOIN executores e ON e.id = ep.executor_id
-- INNER JOIN tasks t ON t.id = ep.task_id
-- WHERE 
--   e.matricula = '264259'
--   AND ep.label = 'Período automático criado por script'
-- ORDER BY ep.data_inicio;
