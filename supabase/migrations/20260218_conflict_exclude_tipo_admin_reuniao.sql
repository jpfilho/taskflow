-- Excluir tarefas do tipo ADMIN, ADM e REUNIAO das regras de conflito (views de conflito).
-- Assim essas tarefas não geram eventos de execução para detecção de conflito.

DROP VIEW IF EXISTS public.v_conflict_por_dia_executor CASCADE;
DROP VIEW IF EXISTS public.v_conflict_execution_events CASCADE;

CREATE OR REPLACE VIEW public.v_conflict_execution_events AS
WITH
  tarefas_incluidas AS (
    SELECT t.id
    FROM tasks t
    WHERE UPPER(TRIM(COALESCE(t.status, ''))) NOT IN ('CANC', 'RPGR', 'REPR', 'RPAR', 'REPROGRAMADA', 'CANCELADA', 'CANCELADO')
      AND (TRIM(COALESCE(t.status, '')) = '' OR (UPPER(TRIM(t.status)) NOT LIKE '%CANC%' AND UPPER(TRIM(t.status)) NOT LIKE '%RPGR%' AND UPPER(TRIM(t.status)) NOT LIKE '%REPR%'))
      AND UPPER(TRIM(COALESCE(t.tipo, ''))) NOT IN ('ADMIN', 'ADM', 'REUNIAO')
  ),
  locs AS (
    SELECT tl.task_id,
      COALESCE(
        (SELECT string_agg(l.id::text, '|' ORDER BY l.id) FROM tasks_locais tl2 JOIN locais l ON l.id = tl2.local_id WHERE tl2.task_id = tl.task_id),
        'task-' || tl.task_id::text
      ) AS loc_key
    FROM (SELECT DISTINCT task_id FROM tasks_locais) tl
    UNION
    SELECT t.id, 'task-' || t.id::text
    FROM tasks t
    WHERE NOT EXISTS (SELECT 1 FROM tasks_locais tl WHERE tl.task_id = t.id)
  ),
  ev_ep_tarefa AS (
    SELECT
      ep.executor_id,
      e.nome AS executor_nome,
      g.day::date AS day,
      COALESCE(l.loc_key, 'task-' || t.id::text) AS location_key,
      t.id AS task_id,
      t.tarefa,
      t.status,
      COALESCE(loc.local, 'Sem local') || ' — ' || COALESCE(NULLIF(TRIM(t.tarefa), ''), 'Tarefa') || ' (Status: ' || COALESCE(TRIM(t.status), '-') || ')' AS description
    FROM executor_periods ep
    JOIN tasks t ON t.id = ep.task_id
    JOIN executores e ON e.id = ep.executor_id
    LEFT JOIN (SELECT task_id, MIN(local) AS local FROM tasks_locais tl2 JOIN locais l ON l.id = tl2.local_id GROUP BY task_id) loc ON loc.task_id = t.id
    LEFT JOIN locs l ON l.task_id = t.id
    CROSS JOIN LATERAL generate_series(
      date(ep.data_inicio)::timestamp,
      date(ep.data_fim)::timestamp,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(TRIM(COALESCE(ep.tipo_periodo, ''))) = 'EXECUCAO'
      AND t.id IN (SELECT id FROM tarefas_incluidas)
      AND ep.data_fim >= date(ep.data_inicio)
      AND (t.parent_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM executor_periods ep2 WHERE ep2.task_id = t.parent_id AND ep2.executor_id = ep.executor_id
      ))
  ),
  ev_ep_pai AS (
    SELECT
      ep.executor_id,
      e.nome AS executor_nome,
      g.day::date AS day,
      COALESCE(l.loc_key, 'task-' || filho.id::text) AS location_key,
      filho.id AS task_id,
      filho.tarefa,
      filho.status,
      COALESCE(loc.local, 'Sem local') || ' — ' || COALESCE(NULLIF(TRIM(filho.tarefa), ''), 'Tarefa') || ' (Status: ' || COALESCE(TRIM(filho.status), '-') || ')' AS description
    FROM tasks filho
    JOIN tasks pai ON pai.id = filho.parent_id
    JOIN executor_periods ep ON ep.task_id = pai.id
    JOIN executores e ON e.id = ep.executor_id
    JOIN tasks_executores te ON te.task_id = filho.id AND te.executor_id = ep.executor_id
    LEFT JOIN (SELECT task_id, MIN(local) AS local FROM tasks_locais tl2 JOIN locais l ON l.id = tl2.local_id GROUP BY task_id) loc ON loc.task_id = filho.id
    LEFT JOIN locs l ON l.task_id = filho.id
    CROSS JOIN LATERAL generate_series(
      date(ep.data_inicio)::timestamp,
      date(ep.data_fim)::timestamp,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(TRIM(COALESCE(ep.tipo_periodo, ''))) = 'EXECUCAO'
      AND filho.id IN (SELECT id FROM tarefas_incluidas)
      AND pai.id IN (SELECT id FROM tarefas_incluidas)
      AND ep.data_fim >= date(ep.data_inicio)
  ),
  ev_gs AS (
    SELECT
      te.executor_id,
      e.nome AS executor_nome,
      g.day::date AS day,
      COALESCE(l.loc_key, 'task-' || t.id::text) AS location_key,
      t.id AS task_id,
      t.tarefa,
      t.status,
      COALESCE(loc.local, 'Sem local') || ' — ' || COALESCE(NULLIF(TRIM(t.tarefa), ''), 'Tarefa') || ' (Status: ' || COALESCE(TRIM(t.status), '-') || ')' AS description
    FROM gantt_segments gs
    JOIN tasks t ON t.id = gs.task_id
    JOIN tasks_executores te ON te.task_id = t.id
    JOIN executores e ON e.id = te.executor_id
    LEFT JOIN (SELECT task_id, MIN(local) AS local FROM tasks_locais tl2 JOIN locais l ON l.id = tl2.local_id GROUP BY task_id) loc ON loc.task_id = t.id
    LEFT JOIN locs l ON l.task_id = t.id
    CROSS JOIN LATERAL generate_series(
      date(gs.data_inicio)::timestamp,
      date(gs.data_fim)::timestamp,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(TRIM(COALESCE(gs.tipo_periodo, ''))) = 'EXECUCAO'
      AND t.id IN (SELECT id FROM tarefas_incluidas)
      AND gs.data_fim >= date(gs.data_inicio)
      AND NOT EXISTS (SELECT 1 FROM executor_periods ep WHERE ep.task_id = t.id AND ep.executor_id = te.executor_id)
      AND (t.parent_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM executor_periods ep2 WHERE ep2.task_id = t.parent_id AND ep2.executor_id = te.executor_id
      ))
      AND NOT EXISTS (SELECT 1 FROM tasks ch WHERE ch.parent_id = t.id)
  ),
  base_events AS (
    SELECT executor_id, executor_nome, day, location_key, task_id, tarefa, status, description FROM ev_ep_tarefa
    UNION
    SELECT executor_id, executor_nome, day, location_key, task_id, tarefa, status, description FROM ev_ep_pai
    UNION
    SELECT executor_id, executor_nome, day, location_key, task_id, tarefa, status, description FROM ev_gs
  ),
  ev_pai_por_filho AS (
    SELECT DISTINCT ON (p.id, be.executor_id, be.day)
      be.executor_id,
      be.executor_nome,
      be.day,
      COALESCE(l.loc_key, 'task-' || p.id::text) AS location_key,
      p.id AS task_id,
      p.tarefa,
      p.status,
      COALESCE(loc.local, 'Sem local') || ' — ' || COALESCE(NULLIF(TRIM(p.tarefa), ''), 'Tarefa') || ' (Status: ' || COALESCE(TRIM(p.status), '-') || ')' AS description
    FROM tasks p
    JOIN tasks_executores te ON te.task_id = p.id
    JOIN tasks filho ON filho.parent_id = p.id
    JOIN base_events be ON be.task_id = filho.id AND be.executor_id = te.executor_id
    LEFT JOIN (SELECT task_id, MIN(local) AS local FROM tasks_locais tl2 JOIN locais l ON l.id = tl2.local_id GROUP BY task_id) loc ON loc.task_id = p.id
    LEFT JOIN locs l ON l.task_id = p.id
    WHERE p.id IN (SELECT id FROM tarefas_incluidas)
  )
SELECT executor_id, executor_nome, day, location_key, task_id, tarefa, status, description FROM base_events
UNION ALL
SELECT executor_id, executor_nome, day, location_key, task_id, tarefa, status, description FROM ev_pai_por_filho;

COMMENT ON VIEW public.v_conflict_execution_events IS
'Eventos de EXECUÇÃO por (executor, dia, local, tarefa) para detecção de conflito. Exclui status CANC/RPGR e tipo ADMIN/ADM/REUNIAO.';

CREATE VIEW public.v_conflict_por_dia_executor AS
WITH ev AS (
  SELECT executor_id, executor_nome, day, location_key, task_id, description
  FROM public.v_conflict_execution_events
),
loc_count AS (
  SELECT executor_id, day, COUNT(DISTINCT NULLIF(TRIM(location_key), '')) AS num_locations
  FROM ev
  GROUP BY executor_id, day
)
SELECT
  ev.executor_id,
  ev.executor_nome,
  ev.day,
  lc.num_locations > 1 AS has_conflict,
  array_agg(DISTINCT ev.description ORDER BY ev.description) FILTER (WHERE ev.description IS NOT NULL AND ev.description != '') AS descriptions
FROM ev
JOIN loc_count lc ON lc.executor_id = ev.executor_id AND lc.day = ev.day
GROUP BY ev.executor_id, ev.executor_nome, ev.day, lc.num_locations;

COMMENT ON VIEW public.v_conflict_por_dia_executor IS
'Conflito por (executor, dia): has_conflict quando mais de um local no mesmo dia. Exclui tipo ADMIN/ADM/REUNIAO.';

GRANT SELECT ON public.v_conflict_execution_events TO authenticated;
GRANT SELECT ON public.v_conflict_execution_events TO anon;
GRANT SELECT ON public.v_conflict_por_dia_executor TO authenticated;
GRANT SELECT ON public.v_conflict_por_dia_executor TO anon;
