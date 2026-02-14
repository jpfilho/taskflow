-- ============================================
-- VIEW NORMAL (NÃO MATERIALIZADA): v_execucoes_dia_completa
-- ============================================
-- Esta view atualiza AUTOMATICAMENTE quando os dados mudam
-- Não precisa de REFRESH - sempre reflete os dados atuais
-- 
-- Inclui TODOS os tipos de períodos:
-- - EXECUCAO (períodos de execução)
-- - PLANEJAMENTO (períodos de planejamento)
-- - DESLOCAMENTO (períodos de deslocamento)
--
-- A view combina dados de:
-- 1. executor_periods (períodos específicos por executor)
-- 2. gantt_segments (períodos gerais da tarefa)
-- ============================================

-- Remover view antiga se existir
DROP VIEW IF EXISTS public.v_execucoes_dia_completa CASCADE;

CREATE VIEW public.v_execucoes_dia_completa AS
WITH
  -- Locais das tarefas
  locs AS (
    SELECT DISTINCT
      tl.task_id,
      COALESCE(l.local, ''::character varying) AS local_nome,
      COALESCE(
        NULLIF(l.id::text, ''::text),
        '__LOCNAME__'::text || COALESCE(l.local, ''::character varying)::text
      ) AS loc_key
    FROM tasks_locais tl
    LEFT JOIN locais l ON l.id = tl.local_id
    WHERE tl.task_id IS NOT NULL
  ),
  
  -- Períodos de EXECUÇÃO de executor_periods
  ep_execucao AS (
    SELECT
      ep.executor_id,
      e.nome AS executor_nome,
      ep.task_id,
      g.day::date AS day,
      t.status AS task_status,
      t.tipo AS task_tipo,
      t.tarefa AS task_tarefa,
      COALESCE(l.local_nome, ''::character varying) AS local_nome,
      COALESCE(l.loc_key, ''::text) AS loc_key,
      'EXECUCAO'::text AS tipo_periodo,
      ep.data_inicio AS periodo_inicio,
      ep.data_fim AS periodo_fim
    FROM executor_periods ep
    JOIN executores e ON e.id = ep.executor_id
    JOIN tasks t ON t.id = ep.task_id
    LEFT JOIN locs l ON l.task_id = ep.task_id
    CROSS JOIN LATERAL generate_series(
      date(ep.data_inicio)::timestamp with time zone,
      date(ep.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(ep.tipo_periodo::text) = 'EXECUCAO'::text
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR')
  ),
  
  -- Períodos de PLANEJAMENTO e DESLOCAMENTO de executor_periods
  ep_planejamento_deslocamento AS (
    SELECT
      ep.executor_id,
      e.nome AS executor_nome,
      ep.task_id,
      g.day::date AS day,
      t.status AS task_status,
      t.tipo AS task_tipo,
      t.tarefa AS task_tarefa,
      COALESCE(l.local_nome, ''::character varying) AS local_nome,
      COALESCE(l.loc_key, ''::text) AS loc_key,
      UPPER(ep.tipo_periodo::text) AS tipo_periodo,
      ep.data_inicio AS periodo_inicio,
      ep.data_fim AS periodo_fim
    FROM executor_periods ep
    JOIN executores e ON e.id = ep.executor_id
    JOIN tasks t ON t.id = ep.task_id
    LEFT JOIN locs l ON l.task_id = ep.task_id
    CROSS JOIN LATERAL generate_series(
      date(ep.data_inicio)::timestamp with time zone,
      date(ep.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(ep.tipo_periodo::text) IN ('PLANEJAMENTO'::text, 'DESLOCAMENTO'::text)
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR')
  ),
  
  -- Segmentos de EXECUÇÃO de gantt_segments
  gs_execucao AS (
    SELECT
      te.executor_id,
      e.nome AS executor_nome,
      gs.task_id,
      g.day::date AS day,
      t.status AS task_status,
      t.tipo AS task_tipo,
      t.tarefa AS task_tarefa,
      COALESCE(l.local_nome, ''::character varying) AS local_nome,
      COALESCE(l.loc_key, ''::text) AS loc_key,
      'EXECUCAO'::text AS tipo_periodo,
      gs.data_inicio AS periodo_inicio,
      gs.data_fim AS periodo_fim
    FROM gantt_segments gs
    JOIN tasks t ON t.id = gs.task_id
    JOIN tasks_executores te ON te.task_id = t.id
    JOIN executores e ON e.id = te.executor_id
    LEFT JOIN locs l ON l.task_id = gs.task_id
    CROSS JOIN LATERAL generate_series(
      date(gs.data_inicio)::timestamp with time zone,
      date(gs.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(gs.tipo_periodo::text) = 'EXECUCAO'::text
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR')
      AND NOT EXISTS (
        SELECT 1
        FROM executor_periods ep
        WHERE ep.task_id = t.id
          AND ep.executor_id = te.executor_id
      )
  ),
  
  -- Segmentos de PLANEJAMENTO e DESLOCAMENTO de gantt_segments
  gs_planejamento_deslocamento AS (
    SELECT
      te.executor_id,
      e.nome AS executor_nome,
      gs.task_id,
      g.day::date AS day,
      t.status AS task_status,
      t.tipo AS task_tipo,
      t.tarefa AS task_tarefa,
      COALESCE(l.local_nome, ''::character varying) AS local_nome,
      COALESCE(l.loc_key, ''::text) AS loc_key,
      UPPER(gs.tipo_periodo::text) AS tipo_periodo,
      gs.data_inicio AS periodo_inicio,
      gs.data_fim AS periodo_fim
    FROM gantt_segments gs
    JOIN tasks t ON t.id = gs.task_id
    JOIN tasks_executores te ON te.task_id = t.id
    JOIN executores e ON e.id = te.executor_id
    LEFT JOIN locs l ON l.task_id = gs.task_id
    CROSS JOIN LATERAL generate_series(
      date(gs.data_inicio)::timestamp with time zone,
      date(gs.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(gs.tipo_periodo::text) IN ('PLANEJAMENTO'::text, 'DESLOCAMENTO'::text)
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR')
      AND NOT EXISTS (
        SELECT 1
        FROM executor_periods ep
        WHERE ep.task_id = t.id
          AND ep.executor_id = te.executor_id
      )
  ),
  
  -- Fallback: usar datas gerais da tarefa quando não há segmentos
  task_base AS (
    SELECT
      te.executor_id,
      e.nome AS executor_nome,
      t.id AS task_id,
      g.day::date AS day,
      t.status AS task_status,
      t.tipo AS task_tipo,
      t.tarefa AS task_tarefa,
      COALESCE(l.local_nome, ''::character varying) AS local_nome,
      COALESCE(l.loc_key, ''::text) AS loc_key,
      'EXECUCAO'::text AS tipo_periodo,
      t.data_inicio AS periodo_inicio,
      t.data_fim AS periodo_fim
    FROM
      tasks t
      JOIN tasks_executores te ON te.task_id = t.id
      JOIN executores e ON e.id = te.executor_id
      LEFT JOIN locs l ON l.task_id = t.id
      CROSS JOIN LATERAL generate_series(
        date(t.data_inicio)::timestamp with time zone,
        date(t.data_fim)::timestamp with time zone,
        '1 day'::interval
      ) g(day)
    WHERE
      t.data_inicio IS NOT NULL
      AND t.data_fim IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM executor_periods ep
        WHERE ep.task_id = t.id
          AND ep.executor_id = te.executor_id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM gantt_segments gs
        WHERE gs.task_id = t.id
      )
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR')
  ),
  
  -- Unir todos os períodos
  unioned AS (
    SELECT * FROM ep_execucao
    UNION ALL
    SELECT * FROM ep_planejamento_deslocamento
    UNION ALL
    SELECT * FROM gs_execucao
    UNION ALL
    SELECT * FROM gs_planejamento_deslocamento
    UNION ALL
    SELECT * FROM task_base
  ),
  
  -- Detectar conflitos (múltiplos locais no mesmo dia)
  -- IMPORTANTE: Conflitos só devem ser detectados para períodos de EXECUÇÃO
  -- Períodos de PLANEJAMENTO e DESLOCAMENTO não geram conflitos
  loc_count AS (
    SELECT
      unioned.executor_id,
      unioned.day,
      COUNT(DISTINCT NULLIF(
        COALESCE(
          NULLIF(unioned.loc_key, ''::text),
          '__LOCNAME__'::text || unioned.local_nome::text
        ),
        ''::text
      )) AS locs_distintos
    FROM unioned
    WHERE UPPER(unioned.tipo_periodo::text) = 'EXECUCAO'::text
    GROUP BY unioned.executor_id, unioned.day
  ),
  
  -- Adicionar flag de conflito
  flagged AS (
    SELECT
      u.executor_id,
      u.executor_nome,
      u.task_id,
      u.day,
      u.task_status,
      u.task_tipo,
      u.task_tarefa,
      u.local_nome,
      u.loc_key,
      u.tipo_periodo,
      u.periodo_inicio,
      u.periodo_fim,
      COALESCE(lc.locs_distintos, 0::bigint) > 1 AS has_conflict
    FROM unioned u
    LEFT JOIN loc_count lc ON lc.executor_id = u.executor_id
      AND lc.day = u.day
  )
SELECT
  flagged.executor_id,
  flagged.executor_nome,
  flagged.task_id,
  flagged.day,
  flagged.task_status,
  flagged.task_tipo,
  flagged.task_tarefa,
  flagged.local_nome,
  flagged.loc_key,
  flagged.tipo_periodo,
  flagged.periodo_inicio,
  flagged.periodo_fim,
  flagged.has_conflict
FROM flagged;

-- Criar índices nas tabelas base para melhorar performance da view
-- (Os índices ajudam mesmo em views normais)
CREATE INDEX IF NOT EXISTS idx_executor_periods_task_executor 
ON public.executor_periods(task_id, executor_id);

CREATE INDEX IF NOT EXISTS idx_executor_periods_tipo_periodo 
ON public.executor_periods(tipo_periodo);

CREATE INDEX IF NOT EXISTS idx_executor_periods_dates 
ON public.executor_periods(data_inicio, data_fim);

CREATE INDEX IF NOT EXISTS idx_gantt_segments_task_tipo_periodo 
ON public.gantt_segments(task_id, tipo_periodo);

CREATE INDEX IF NOT EXISTS idx_tasks_executores_task_executor 
ON public.tasks_executores(task_id, executor_id);

CREATE INDEX IF NOT EXISTS idx_tasks_locais_task_local 
ON public.tasks_locais(task_id, local_id);

-- ============================================
-- COMENTÁRIOS
-- ============================================
COMMENT ON VIEW public.v_execucoes_dia_completa IS 
'View normal (não materializada) que inclui TODOS os tipos de períodos (EXECUCAO, PLANEJAMENTO, DESLOCAMENTO) 
de executor_periods e gantt_segments. Exclui tarefas CANC (canceladas) e REPR (reprogramadas). 
ATUALIZA AUTOMATICAMENTE quando os dados mudam - não precisa de REFRESH.';
