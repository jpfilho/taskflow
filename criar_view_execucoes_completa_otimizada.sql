-- ============================================
-- VIEW NORMAL OTIMIZADA: v_execucoes_dia_completa (FIXED: Inclui Equipes)
-- ============================================
-- Esta versão OTIMIZADA filtra períodos ANTES de expandir em dias
-- CORREÇÃO: Adicionado join com tasks_equipes para capturar todos os executores
-- ============================================

-- Remover view antiga se existir
DROP VIEW IF EXISTS public.v_execucoes_dia_completa CASCADE;

CREATE VIEW public.v_execucoes_dia_completa AS
WITH
  -- Locais das tarefas (mantém como está)
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
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND ep.data_fim >= CURRENT_DATE - INTERVAL '1 year'
      AND ep.data_inicio <= CURRENT_DATE + INTERVAL '2 years'
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
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND ep.data_fim >= CURRENT_DATE - INTERVAL '1 year'
      AND ep.data_inicio <= CURRENT_DATE + INTERVAL '2 years'
  ),
  
  -- Segmentos de EXECUÇÃO de gantt_segments (via tasks_executores)
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
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND NOT EXISTS (
        SELECT 1 FROM executor_periods ep 
        WHERE ep.task_id = t.id AND ep.executor_id = te.executor_id
      )
      AND gs.data_fim >= CURRENT_DATE - INTERVAL '1 year'
      AND gs.data_inicio <= CURRENT_DATE + INTERVAL '2 years'
  ),

  -- Segmentos de EXECUÇÃO via EQUIPES
  gs_execucao_equipes AS (
    SELECT
      ee.executor_id,
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
    JOIN tasks_equipes teq ON teq.task_id = t.id
    JOIN equipes_executores ee ON ee.equipe_id = teq.equipe_id
    JOIN executores e ON e.id = ee.executor_id
    LEFT JOIN locs l ON l.task_id = gs.task_id
    CROSS JOIN LATERAL generate_series(
      date(gs.data_inicio)::timestamp with time zone,
      date(gs.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(gs.tipo_periodo::text) = 'EXECUCAO'::text
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND NOT EXISTS (
        SELECT 1 FROM executor_periods ep 
        WHERE ep.task_id = t.id AND ep.executor_id = ee.executor_id
      )
      AND gs.data_fim >= CURRENT_DATE - INTERVAL '1 year'
      AND gs.data_inicio <= CURRENT_DATE + INTERVAL '2 years'
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
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND NOT EXISTS (
        SELECT 1 FROM executor_periods ep 
        WHERE ep.task_id = t.id AND ep.executor_id = te.executor_id
      )
      AND gs.data_fim >= CURRENT_DATE - INTERVAL '1 year'
      AND gs.data_inicio <= CURRENT_DATE + INTERVAL '2 years'
  ),

  -- Segmentos de PLANEJAMENTO e DESLOCAMENTO via EQUIPES
  gs_planejamento_deslocamento_equipes AS (
    SELECT
      ee.executor_id,
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
    JOIN tasks_equipes teq ON teq.task_id = t.id
    JOIN equipes_executores ee ON ee.equipe_id = teq.equipe_id
    JOIN executores e ON e.id = ee.executor_id
    LEFT JOIN locs l ON l.task_id = gs.task_id
    CROSS JOIN LATERAL generate_series(
      date(gs.data_inicio)::timestamp with time zone,
      date(gs.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(gs.tipo_periodo::text) IN ('PLANEJAMENTO'::text, 'DESLOCAMENTO'::text)
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND NOT EXISTS (
        SELECT 1 FROM executor_periods ep 
        WHERE ep.task_id = t.id AND ep.executor_id = ee.executor_id
      )
      AND gs.data_fim >= CURRENT_DATE - INTERVAL '1 year'
      AND gs.data_inicio <= CURRENT_DATE + INTERVAL '2 years'
  ),
  
  -- Fallback: usar datas gerais da tarefa quando não há segmentos (via tasks_executores)
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
      t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM executor_periods ep WHERE ep.task_id = t.id AND ep.executor_id = te.executor_id)
      AND NOT EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id)
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND t.data_fim >= CURRENT_DATE - INTERVAL '1 year'
      AND t.data_inicio <= CURRENT_DATE + INTERVAL '2 years'
  ),

  -- Fallback via EQUIPES
  task_base_equipes AS (
    SELECT
      ee.executor_id,
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
      JOIN tasks_equipes teq ON teq.task_id = t.id
      JOIN equipes_executores ee ON ee.equipe_id = teq.equipe_id
      JOIN executores e ON e.id = ee.executor_id
      LEFT JOIN locs l ON l.task_id = t.id
      CROSS JOIN LATERAL generate_series(
        date(t.data_inicio)::timestamp with time zone,
        date(t.data_fim)::timestamp with time zone,
        '1 day'::interval
      ) g(day)
    WHERE
      t.data_inicio IS NOT NULL AND t.data_fim IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM executor_periods ep WHERE ep.task_id = t.id AND ep.executor_id = ee.executor_id)
      AND NOT EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id)
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'REPR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND t.data_fim >= CURRENT_DATE - INTERVAL '1 year'
      AND t.data_inicio <= CURRENT_DATE + INTERVAL '2 years'
  ),
  
  -- Unir todos os períodos (Removido DISTINCT para performance, view usará UNION ALL)
  unioned AS (
    SELECT * FROM ep_execucao
    UNION ALL
    SELECT * FROM ep_planejamento_deslocamento
    UNION ALL
    SELECT * FROM gs_execucao
    UNION ALL
    SELECT * FROM gs_execucao_equipes
    UNION ALL
    SELECT * FROM gs_planejamento_deslocamento
    UNION ALL
    SELECT * FROM gs_planejamento_deslocamento_equipes
    UNION ALL
    SELECT * FROM task_base
    UNION ALL
    SELECT * FROM task_base_equipes
  ),
  
  -- Detectar conflitos (múltiplos locais no mesmo dia)
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
  )
  
SELECT DISTINCT
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
LEFT JOIN loc_count lc ON lc.executor_id = u.executor_id AND lc.day = u.day;

COMMENT ON VIEW public.v_execucoes_dia_completa IS 
'View normal (não materializada) OTIMIZADA que inclui TODOS os tipos de períodos (EXECUCAO, PLANEJAMENTO, DESLOCAMENTO) 
de executor_periods, gantt_segments e atribuições via EQUIPES. Exclui tarefas CANC (canceladas) e REPR (reprogramadas).';
