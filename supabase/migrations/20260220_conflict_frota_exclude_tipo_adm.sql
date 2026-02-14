-- Excluir também tipo ADM (código de "Atividade Admin") das views de conflito de frota.
-- Quem já aplicou 20260219 deve aplicar esta migration para que atividades ADMIN/ADM não apareçam como conflito na tela Frota.

DROP VIEW IF EXISTS public.v_conflict_por_dia_frota CASCADE;
DROP VIEW IF EXISTS public.v_conflict_execution_events_frota CASCADE;

CREATE VIEW public.v_conflict_execution_events_frota AS
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
  ev_fp AS (
    SELECT
      fp.frota_id,
      COALESCE(f.nome || ' - ' || f.placa, fp.frota_nome, ''::text) AS frota_nome,
      g.day::date AS day,
      COALESCE(l.loc_key, 'task-' || t.id::text) AS location_key,
      t.id AS task_id,
      t.tarefa,
      t.status,
      COALESCE(loc.local, 'Sem local') || ' — ' || COALESCE(NULLIF(TRIM(t.tarefa), ''), 'Tarefa') || ' (Status: ' || COALESCE(TRIM(t.status), '-') || ')' AS description
    FROM frota_periods fp
    JOIN tasks t ON t.id = fp.task_id
    LEFT JOIN frota f ON f.id = fp.frota_id
    LEFT JOIN (SELECT task_id, MIN(local) AS local FROM tasks_locais tl2 JOIN locais l ON l.id = tl2.local_id GROUP BY task_id) loc ON loc.task_id = t.id
    LEFT JOIN locs l ON l.task_id = t.id
    CROSS JOIN LATERAL generate_series(
      date(fp.data_inicio)::timestamp,
      date(fp.data_fim)::timestamp,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(TRIM(COALESCE(fp.tipo_periodo, ''))) = 'EXECUCAO'
      AND t.id IN (SELECT id FROM tarefas_incluidas)
      AND fp.data_fim >= date(fp.data_inicio)
  ),
  ev_gs_frota AS (
    SELECT
      tf.frota_id,
      COALESCE(f.nome || ' - ' || f.placa, f.nome, ''::text) AS frota_nome,
      g.day::date AS day,
      COALESCE(l.loc_key, 'task-' || t.id::text) AS location_key,
      t.id AS task_id,
      t.tarefa,
      t.status,
      COALESCE(loc.local, 'Sem local') || ' — ' || COALESCE(NULLIF(TRIM(t.tarefa), ''), 'Tarefa') || ' (Status: ' || COALESCE(TRIM(t.status), '-') || ')' AS description
    FROM gantt_segments gs
    JOIN tasks t ON t.id = gs.task_id
    JOIN tasks_frotas tf ON tf.task_id = t.id
    LEFT JOIN frota f ON f.id = tf.frota_id
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
      AND NOT EXISTS (SELECT 1 FROM frota_periods fp WHERE fp.task_id = t.id AND fp.frota_id = tf.frota_id)
      AND NOT EXISTS (SELECT 1 FROM tasks ch WHERE ch.parent_id = t.id)
  ),
  ev_task_base AS (
    SELECT
      tf.frota_id,
      COALESCE(f.nome || ' - ' || f.placa, f.nome, ''::text) AS frota_nome,
      g.day::date AS day,
      COALESCE(l.loc_key, 'task-' || t.id::text) AS location_key,
      t.id AS task_id,
      t.tarefa,
      t.status,
      COALESCE(loc.local, 'Sem local') || ' — ' || COALESCE(NULLIF(TRIM(t.tarefa), ''), 'Tarefa') || ' (Status: ' || COALESCE(TRIM(t.status), '-') || ')' AS description
    FROM tasks t
    JOIN tasks_frotas tf ON tf.task_id = t.id
    LEFT JOIN frota f ON f.id = tf.frota_id
    LEFT JOIN (SELECT task_id, MIN(local) AS local FROM tasks_locais tl2 JOIN locais l ON l.id = tl2.local_id GROUP BY task_id) loc ON loc.task_id = t.id
    LEFT JOIN locs l ON l.task_id = t.id
    CROSS JOIN LATERAL generate_series(
      date(t.data_inicio)::timestamp,
      date(t.data_fim)::timestamp,
      '1 day'::interval
    ) g(day)
    WHERE t.id IN (SELECT id FROM tarefas_incluidas)
      AND t.data_inicio IS NOT NULL
      AND t.data_fim IS NOT NULL
      AND t.data_fim >= date(t.data_inicio)
      AND NOT EXISTS (SELECT 1 FROM frota_periods fp WHERE fp.task_id = t.id AND fp.frota_id = tf.frota_id)
      AND NOT EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id)
  ),
  base_events AS (
    SELECT frota_id, frota_nome, day, location_key, task_id, tarefa, status, description FROM ev_fp
    UNION
    SELECT frota_id, frota_nome, day, location_key, task_id, tarefa, status, description FROM ev_gs_frota
    UNION
    SELECT frota_id, frota_nome, day, location_key, task_id, tarefa, status, description FROM ev_task_base
  )
SELECT frota_id, frota_nome, day, location_key, task_id, tarefa, status, description FROM base_events;

COMMENT ON VIEW public.v_conflict_execution_events_frota IS
'Eventos de EXECUÇÃO por (frota, dia, local, tarefa). Exclui CANC/RPGR e tipo ADMIN/ADM/REUNIAO.';

CREATE VIEW public.v_conflict_por_dia_frota AS
WITH ev AS (
  SELECT frota_id, frota_nome, day, location_key, task_id, description
  FROM public.v_conflict_execution_events_frota
),
loc_count AS (
  SELECT frota_id, day, COUNT(DISTINCT NULLIF(TRIM(location_key), '')) AS num_locations
  FROM ev
  GROUP BY frota_id, day
)
SELECT
  ev.frota_id,
  ev.frota_nome,
  ev.day,
  lc.num_locations > 1 AS has_conflict,
  array_agg(DISTINCT ev.description ORDER BY ev.description) FILTER (WHERE ev.description IS NOT NULL AND ev.description != '') AS descriptions
FROM ev
JOIN loc_count lc ON lc.frota_id = ev.frota_id AND lc.day = ev.day
GROUP BY ev.frota_id, ev.frota_nome, ev.day, lc.num_locations;

COMMENT ON VIEW public.v_conflict_por_dia_frota IS
'Conflito por (frota, dia): has_conflict quando mais de um local no mesmo dia. Exclui tipo ADMIN/ADM/REUNIAO.';

GRANT SELECT ON public.v_conflict_execution_events_frota TO authenticated;
GRANT SELECT ON public.v_conflict_execution_events_frota TO anon;
GRANT SELECT ON public.v_conflict_por_dia_frota TO authenticated;
GRANT SELECT ON public.v_conflict_por_dia_frota TO anon;
