-- ============================================
-- VIEW MATERIALIZADA: mv_execucoes_dia_completa
-- ============================================
-- Esta view inclui TODOS os tipos de períodos:
-- - EXECUCAO (períodos de execução)
-- - PLANEJAMENTO (períodos de planejamento)
-- - DESLOCAMENTO (períodos de deslocamento)
--
-- A view combina dados de:
-- 1. executor_periods (períodos específicos por executor)
-- 2. gantt_segments (períodos gerais da tarefa)
--
-- IMPORTANTE: Esta view substitui a lógica de buscar períodos separadamente
-- e já retorna todos os períodos com o campo tipo_periodo incluído
-- ============================================

DROP MATERIALIZED VIEW IF EXISTS public.mv_execucoes_dia_completa CASCADE;

CREATE MATERIALIZED VIEW public.mv_execucoes_dia_completa AS
WITH
  -- Locais das tarefas
  locs AS (
    SELECT
      t.id AS task_id,
      COALESCE(l.local, t.local, ''::character varying) AS local_nome,
      COALESCE(l.id::text, t.local_id::text, ''::text) AS loc_key
    FROM
      tasks t
      LEFT JOIN locais l ON l.id = t.local_id
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
    FROM
      executor_periods ep
      JOIN tasks t ON t.id = ep.task_id
      JOIN executores e ON e.id = ep.executor_id
      LEFT JOIN locs l ON l.task_id = t.id
      CROSS JOIN LATERAL generate_series(
        date(ep.data_inicio)::timestamp with time zone,
        date(ep.data_fim)::timestamp with time zone,
        '1 day'::interval
      ) g(day)
    WHERE
      UPPER(ep.tipo_periodo::text) = 'EXECUCAO'::text
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
    FROM
      executor_periods ep
      JOIN tasks t ON t.id = ep.task_id
      JOIN executores e ON e.id = ep.executor_id
      LEFT JOIN locs l ON l.task_id = t.id
      CROSS JOIN LATERAL generate_series(
        date(ep.data_inicio)::timestamp with time zone,
        date(ep.data_fim)::timestamp with time zone,
        '1 day'::interval
      ) g(day)
    WHERE
      UPPER(ep.tipo_periodo::text) IN ('PLANEJAMENTO', 'DESLOCAMENTO')
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR')
  ),
  
  -- Períodos de EXECUÇÃO de gantt_segments (quando não há executor_periods)
  gs_execucao AS (
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
      gs.data_inicio AS periodo_inicio,
      gs.data_fim AS periodo_fim
    FROM
      tasks t
      JOIN tasks_executores te ON te.task_id = t.id
      JOIN executores e ON e.id = te.executor_id
      LEFT JOIN locs l ON l.task_id = t.id
      JOIN gantt_segments gs ON gs.task_id = t.id
      CROSS JOIN LATERAL generate_series(
        date(gs.data_inicio)::timestamp with time zone,
        date(gs.data_fim)::timestamp with time zone,
        '1 day'::interval
      ) g(day)
    WHERE
      NOT EXISTS (
        SELECT 1
        FROM executor_periods ep
        WHERE ep.task_id = t.id
          AND ep.executor_id = te.executor_id
      )
      AND UPPER(gs.tipo_periodo::text) = 'EXECUCAO'::text
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR')
  ),
  
  -- Períodos de PLANEJAMENTO e DESLOCAMENTO de gantt_segments
  gs_planejamento_deslocamento AS (
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
      UPPER(gs.tipo_periodo::text) AS tipo_periodo,
      gs.data_inicio AS periodo_inicio,
      gs.data_fim AS periodo_fim
    FROM
      tasks t
      JOIN tasks_executores te ON te.task_id = t.id
      JOIN executores e ON e.id = te.executor_id
      LEFT JOIN locs l ON l.task_id = t.id
      JOIN gantt_segments gs ON gs.task_id = t.id
      CROSS JOIN LATERAL generate_series(
        date(gs.data_inicio)::timestamp with time zone,
        date(gs.data_fim)::timestamp with time zone,
        '1 day'::interval
      ) g(day)
    WHERE
      UPPER(gs.tipo_periodo::text) IN ('PLANEJAMENTO', 'DESLOCAMENTO')
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR')
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

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_mv_execucoes_dia_completa_executor_day 
ON public.mv_execucoes_dia_completa(executor_id, day);

CREATE INDEX IF NOT EXISTS idx_mv_execucoes_dia_completa_task_id 
ON public.mv_execucoes_dia_completa(task_id);

CREATE INDEX IF NOT EXISTS idx_mv_execucoes_dia_completa_tipo_periodo 
ON public.mv_execucoes_dia_completa(tipo_periodo);

CREATE INDEX IF NOT EXISTS idx_mv_execucoes_dia_completa_day 
ON public.mv_execucoes_dia_completa(day);

-- ============================================
-- FUNÇÃO PARA REFRESH DA VIEW
-- ============================================
CREATE OR REPLACE FUNCTION refresh_mv_execucoes_dia_completa()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_execucoes_dia_completa;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- COMENTÁRIOS
-- ============================================
COMMENT ON MATERIALIZED VIEW public.mv_execucoes_dia_completa IS 
'View materializada que inclui TODOS os tipos de períodos (EXECUCAO, PLANEJAMENTO, DESLOCAMENTO) 
de executor_periods e gantt_segments. Exclui tarefas CANC (canceladas) e REPR (reprogramadas). 
Use refresh_mv_execucoes_dia_completa() para atualizar.';

COMMENT ON FUNCTION refresh_mv_execucoes_dia_completa() IS 
'Atualiza a view materializada mv_execucoes_dia_completa. 
Execute após alterações em executor_periods ou gantt_segments.';
