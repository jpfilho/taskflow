-- ==============================================================================
-- TASKFLOW: INSTALAÇÃO CONSOLIDADA DE ALERTAS (TASK WARNINGS W1-W5) EM PRODUÇÃO
-- ARQUIVO: 08_task_warnings_completo.sql
-- ==============================================================================
-- Este script instala todas as dependências necessárias para a coluna "Alerta"
-- na tabela de atividades:
--   1. Encerramento SAP (W2): Função status_sistema_encerrado e view tasks_conc_encerramento_sap
--   2. Conflitos de Executores (W3): v_conflict_execution_events e v_conflict_por_dia_executor
--   3. Conflitos de Frota (W4): v_conflict_execution_events_frota e v_conflict_por_dia_frota
--   4. View Base de Alertas: v_task_warnings_base (W1 a W5)
--   5. RPC Supabase: get_task_warnings_for_user(p_user_id UUID) com timeout de 60s
--   6. Índices de performance e permissões GRANT para authenticated e anon
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FUNÇÃO E VIEWS DE ENCERRAMENTO SAP (NECESSÁRIO PARA W2)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.status_sistema_encerrado(p_status_sistema TEXT)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    UPPER(TRIM(p_status_sistema)) LIKE '%ENTE%'
    OR UPPER(TRIM(p_status_sistema)) LIKE '%ENCE%'
    OR UPPER(TRIM(p_status_sistema)) LIKE '%MSEN%',
    FALSE
  );
$$;

DROP VIEW IF EXISTS public.tasks_conc_encerramento_sap CASCADE;

CREATE VIEW public.tasks_conc_encerramento_sap AS
WITH conc_tasks AS (
  SELECT id AS task_id, tarefa, status, regional, divisao, tipo, ordem AS ordem_txt, data_inicio, data_fim
  FROM public.tasks
  WHERE UPPER(TRIM(status)) = 'CONC'
),
notas_nao_encerradas AS (
  SELECT
    tns.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_notas_sap tns
  INNER JOIN public.notas_sap ns ON ns.id = tns.nota_sap_id
  INNER JOIN conc_tasks ct ON ct.task_id = tns.task_id
  WHERE NOT public.status_sistema_encerrado(ns.status_sistema)
  GROUP BY tns.task_id
),
ordens_nao_encerradas AS (
  SELECT
    to_rel.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_ordens to_rel
  INNER JOIN public.ordens o ON o.id = to_rel.ordem_id
  INNER JOIN conc_tasks ct ON ct.task_id = to_rel.task_id
  WHERE NOT public.status_sistema_encerrado(o.status_sistema)
  GROUP BY to_rel.task_id
),
ats_nao_encerradas AS (
  SELECT
    ta.task_id,
    COUNT(*) AS qtd
  FROM public.tasks_ats ta
  INNER JOIN public.ats a ON a.id = ta.at_id
  INNER JOIN conc_tasks ct ON ct.task_id = ta.task_id
  WHERE NOT public.status_sistema_encerrado(a.status_sistema)
  GROUP BY ta.task_id
)
SELECT
  ct.task_id,
  ct.tarefa,
  ct.status,
  ct.regional,
  ct.divisao,
  ct.tipo,
  ct.ordem_txt,
  ct.data_inicio,
  ct.data_fim,
  COALESCE(nn.qtd, 0)::INTEGER AS qtd_notas_nao_encerradas,
  COALESCE(on_.qtd, 0)::INTEGER AS qtd_ordens_nao_encerradas,
  COALESCE(an.qtd, 0)::INTEGER AS qtd_ats_nao_encerradas,
  (COALESCE(nn.qtd, 0) + COALESCE(on_.qtd, 0) + COALESCE(an.qtd, 0)) > 0 AS tem_algum_nao_encerrado
FROM conc_tasks ct
LEFT JOIN notas_nao_encerradas nn ON nn.task_id = ct.task_id
LEFT JOIN ordens_nao_encerradas on_ ON on_.task_id = ct.task_id
LEFT JOIN ats_nao_encerradas an ON an.task_id = ct.task_id;

GRANT SELECT ON public.tasks_conc_encerramento_sap TO authenticated;
GRANT SELECT ON public.tasks_conc_encerramento_sap TO anon;


-- ------------------------------------------------------------------------------
-- 2. VIEWS DE CONFLITO DE EXECUTORES (NECESSÁRIO PARA W3)
-- ------------------------------------------------------------------------------

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
      COALESCE(l.loc_key, 'task-' || t.id::text) AS location_key,
      t.id AS task_id,
      t.tarefa,
      t.status,
      COALESCE(loc.local, 'Sem local') || ' — ' || COALESCE(NULLIF(TRIM(t.tarefa), ''), 'Tarefa') || ' (Status: ' || COALESCE(TRIM(t.status), '-') || ')' AS description
    FROM tasks t
    JOIN executor_periods ep ON ep.task_id = t.parent_id
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
      AND t.parent_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM executor_periods ep_self WHERE ep_self.task_id = t.id AND ep_self.executor_id = ep.executor_id
      )
  ),
  ev_gs_tarefa AS (
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
      AND NOT EXISTS (
        SELECT 1 FROM executor_periods ep WHERE ep.task_id = t.id AND ep.executor_id = te.executor_id
      )
      AND (t.parent_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM executor_periods ep2 WHERE ep2.task_id = t.parent_id AND ep2.executor_id = te.executor_id
      ))
  ),
  all_ev AS (
    SELECT * FROM ev_ep_tarefa
    UNION ALL
    SELECT * FROM ev_ep_pai
    UNION ALL
    SELECT * FROM ev_gs_tarefa
  )
SELECT DISTINCT executor_id, executor_nome, day, location_key, task_id, tarefa, status, description
FROM all_ev;

GRANT SELECT ON public.v_conflict_execution_events TO authenticated;
GRANT SELECT ON public.v_conflict_execution_events TO anon;

CREATE OR REPLACE VIEW public.v_conflict_por_dia_executor AS
SELECT
  executor_id,
  executor_nome,
  day,
  COUNT(DISTINCT task_id) > 1 AS has_conflict,
  COUNT(DISTINCT task_id) AS total_tasks,
  string_agg(DISTINCT description, ' | ') AS descriptions
FROM public.v_conflict_execution_events
GROUP BY executor_id, executor_nome, day;

GRANT SELECT ON public.v_conflict_por_dia_executor TO authenticated;
GRANT SELECT ON public.v_conflict_por_dia_executor TO anon;


-- ------------------------------------------------------------------------------
-- 3. VIEWS DE CONFLITO DE FROTA (NECESSÁRIO PARA W4)
-- ------------------------------------------------------------------------------

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
      AND NOT EXISTS (
        SELECT 1 FROM frota_periods fp WHERE fp.task_id = t.id AND fp.frota_id = tf.frota_id
      )
  ),
  all_ev AS (
    SELECT * FROM ev_fp
    UNION ALL
    SELECT * FROM ev_gs_frota
  )
SELECT DISTINCT frota_id, frota_nome, day, location_key, task_id, tarefa, status, description
FROM all_ev;

GRANT SELECT ON public.v_conflict_execution_events_frota TO authenticated;
GRANT SELECT ON public.v_conflict_execution_events_frota TO anon;

CREATE VIEW public.v_conflict_por_dia_frota AS
SELECT
  frota_id,
  frota_nome,
  day,
  COUNT(DISTINCT task_id) > 1 AS has_conflict,
  COUNT(DISTINCT task_id) AS total_tasks,
  string_agg(DISTINCT description, ' | ') AS descriptions
FROM public.v_conflict_execution_events_frota
GROUP BY frota_id, frota_nome, day;

GRANT SELECT ON public.v_conflict_por_dia_frota TO authenticated;
GRANT SELECT ON public.v_conflict_por_dia_frota TO anon;


-- ------------------------------------------------------------------------------
-- 4. VIEW BASE DE ALERTAS (v_task_warnings_base: W1, W2, W3, W4, W5)
-- ------------------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_task_warnings_base CASCADE;

CREATE VIEW public.v_task_warnings_base AS
WITH task_scope AS (
  SELECT
    t.id AS task_id,
    t.status,
    t.status_id,
    t.data_inicio,
    t.data_fim,
    t.updated_at AS task_updated_at,
    t.coordenador,
    t.regional_id,
    t.divisao_id,
    t.segmento_id
  FROM public.tasks t
),
today_br AS (
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date AS d
),
-- W1: Status PROG/ANDA após data final
w1_candidates AS (
  SELECT
    ts.task_id,
    'W1'::TEXT AS warning_code,
    'HIGH'::TEXT AS severity,
    'Tarefa está com status PROG/ANDA após a data final.'::TEXT AS message,
    'Atualizar o status da tarefa para o status correto (ex.: CONC, CANC, etc.) ou ajustar datas.'::TEXT AS fix_hint,
    jsonb_build_object(
      'status_atual', ts.status,
      'data_fim', ts.data_fim,
      'hoje', br.d
    ) AS details_json,
    CURRENT_TIMESTAMP AS created_at,
    ts.task_updated_at,
    ts.regional_id,
    ts.divisao_id,
    ts.segmento_id
  FROM task_scope ts
  CROSS JOIN today_br br
  WHERE (ts.data_fim IS NOT NULL AND (ts.data_fim)::date < br.d)
    AND UPPER(TRIM(COALESCE(ts.status, ''))) IN ('PROG', 'ANDA')
),
-- W2: CONC com pendência SAP
w2_source AS (
  SELECT task_id, qtd_notas_nao_encerradas, qtd_ordens_nao_encerradas, qtd_ats_nao_encerradas
  FROM public.tasks_conc_encerramento_sap
  WHERE tem_algum_nao_encerrado = TRUE
),
w2_candidates AS (
  SELECT
    ts.task_id,
    'W2'::TEXT AS warning_code,
    'HIGH'::TEXT AS severity,
    'Tarefa CONC com pendências de encerramento SAP.'::TEXT AS message,
    'Encerrar no SAP a Nota/Ordem/AT pendente e aguardar sincronização.'::TEXT AS fix_hint,
    jsonb_build_object(
      'status_atual', ts.status,
      'qtd_notas_nao_encerradas', COALESCE(w2.qtd_notas_nao_encerradas, 0),
      'qtd_ordens_nao_encerradas', COALESCE(w2.qtd_ordens_nao_encerradas, 0),
      'qtd_ats_nao_encerradas', COALESCE(w2.qtd_ats_nao_encerradas, 0)
    ) AS details_json,
    CURRENT_TIMESTAMP AS created_at,
    ts.task_updated_at,
    ts.regional_id,
    ts.divisao_id,
    ts.segmento_id
  FROM task_scope ts
  INNER JOIN w2_source w2 ON w2.task_id = ts.task_id
),
-- W3: Conflito de Executor
w3_grp AS (
  SELECT
    e.executor_id,
    e.executor_nome,
    e.day,
    jsonb_agg(jsonb_build_object('titulo', COALESCE(e.tarefa, '')) ORDER BY e.task_id) AS tasks_conflitantes
  FROM public.v_conflict_execution_events e
  INNER JOIN public.v_conflict_por_dia_executor c ON c.executor_id = e.executor_id AND c.day = e.day AND c.has_conflict
  GROUP BY e.executor_id, e.executor_nome, e.day
),
w3_one_per_task AS (
  SELECT DISTINCT ON (e.task_id)
    e.task_id,
    e.executor_nome,
    e.day,
    g.tasks_conflitantes
  FROM public.v_conflict_execution_events e
  INNER JOIN public.v_conflict_por_dia_executor c ON c.executor_id = e.executor_id AND c.day = e.day AND c.has_conflict
  INNER JOIN w3_grp g ON g.executor_id = e.executor_id AND g.day = e.day
  ORDER BY e.task_id, e.day
),
w3_candidates AS (
  SELECT
    w.task_id,
    'W3'::TEXT AS warning_code,
    'HIGH'::TEXT AS severity,
    'Conflito de executor: o mesmo executor está alocado em mais de uma tarefa no mesmo período.'::TEXT AS message,
    'Replanejar datas/segmentos, remover executor de uma das tarefas ou ajustar segmentos para não sobrepor.'::TEXT AS fix_hint,
    jsonb_build_object(
      'executor_nome', w.executor_nome,
      'data', w.day,
      'tasks_conflitantes', w.tasks_conflitantes
    ) AS details_json,
    CURRENT_TIMESTAMP AS created_at,
    t.updated_at AS task_updated_at,
    t.regional_id,
    t.divisao_id,
    t.segmento_id
  FROM w3_one_per_task w
  INNER JOIN public.tasks t ON t.id = w.task_id
),
-- W4: Conflito de Frota
w4_grp AS (
  SELECT
    e.frota_id,
    e.frota_nome,
    e.day,
    jsonb_agg(jsonb_build_object('titulo', COALESCE(e.tarefa, '')) ORDER BY e.task_id) AS tasks_conflitantes
  FROM public.v_conflict_execution_events_frota e
  INNER JOIN public.v_conflict_por_dia_frota c ON c.frota_id = e.frota_id AND c.day = e.day AND c.has_conflict
  GROUP BY e.frota_id, e.frota_nome, e.day
),
w4_one_per_task AS (
  SELECT DISTINCT ON (e.task_id)
    e.task_id,
    e.frota_nome,
    e.day,
    g.tasks_conflitantes
  FROM public.v_conflict_execution_events_frota e
  INNER JOIN public.v_conflict_por_dia_frota c ON c.frota_id = e.frota_id AND c.day = e.day AND c.has_conflict
  INNER JOIN w4_grp g ON g.frota_id = e.frota_id AND g.day = e.day
  ORDER BY e.task_id, e.day
),
w4_candidates AS (
  SELECT
    w.task_id,
    'W4'::TEXT AS warning_code,
    'HIGH'::TEXT AS severity,
    'Conflito de frota: o mesmo veículo está alocado em mais de uma tarefa no mesmo período.'::TEXT AS message,
    'Replanejar datas/segmentos, trocar frota em uma das tarefas ou segmentar para evitar sobreposição.'::TEXT AS fix_hint,
    jsonb_build_object(
      'frota_nome', COALESCE(w.frota_nome, ''),
      'data', w.day,
      'tasks_conflitantes', w.tasks_conflitantes
    ) AS details_json,
    CURRENT_TIMESTAMP AS created_at,
    t.updated_at AS task_updated_at,
    t.regional_id,
    t.divisao_id,
    t.segmento_id
  FROM w4_one_per_task w
  INNER JOIN public.tasks t ON t.id = w.task_id
),
-- W5: Programado mas já deveria ter iniciado
w5_candidates AS (
  SELECT
    ts.task_id,
    'W5'::TEXT AS warning_code,
    'MEDIUM'::TEXT AS severity,
    'Período programado já iniciou e a tarefa ainda está como PROG.'::TEXT AS message,
    'O coordenador deve atualizar o status para ANDA (iniciou), CANCEL (cancelado) ou ajustar datas (reprogramado).'::TEXT AS fix_hint,
    jsonb_build_object(
      'status_atual', ts.status,
      'data_inicio', ts.data_inicio,
      'data_fim', ts.data_fim,
      'dias_desde_inicio', (br.d - (ts.data_inicio)::date)
    ) AS details_json,
    CURRENT_TIMESTAMP AS created_at,
    ts.task_updated_at,
    ts.regional_id,
    ts.divisao_id,
    ts.segmento_id
  FROM task_scope ts
  CROSS JOIN today_br br
  LEFT JOIN public.status st ON st.id = ts.status_id
  WHERE UPPER(TRIM(COALESCE(ts.status, ''))) = 'PROG'
    AND UPPER(TRIM(COALESCE(ts.status, ''))) NOT IN ('RPGR', 'REPR')
    AND (st.id IS NULL OR UPPER(TRIM(COALESCE(st.codigo, ''))) <> 'RPGR')
    AND ts.data_inicio IS NOT NULL
    AND (ts.data_inicio)::date <= br.d
    AND (ts.data_fim IS NULL OR (ts.data_fim)::date >= br.d)
),
all_warnings AS (
  SELECT task_id, warning_code, severity, message, fix_hint, details_json, created_at, task_updated_at, regional_id, divisao_id, segmento_id FROM w1_candidates
  UNION ALL
  SELECT task_id, warning_code, severity, message, fix_hint, details_json, created_at, task_updated_at, regional_id, divisao_id, segmento_id FROM w2_candidates
  UNION ALL
  SELECT task_id, warning_code, severity, message, fix_hint, details_json, created_at, task_updated_at, regional_id, divisao_id, segmento_id FROM w3_candidates
  UNION ALL
  SELECT task_id, warning_code, severity, message, fix_hint, details_json, created_at, task_updated_at, regional_id, divisao_id, segmento_id FROM w4_candidates
  UNION ALL
  SELECT task_id, warning_code, severity, message, fix_hint, details_json, created_at, task_updated_at, regional_id, divisao_id, segmento_id FROM w5_candidates
)
SELECT
  aw.task_id,
  aw.warning_code,
  aw.severity,
  aw.message,
  aw.fix_hint,
  aw.details_json,
  aw.created_at,
  aw.task_updated_at,
  aw.regional_id,
  aw.divisao_id,
  aw.segmento_id
FROM all_warnings aw;

COMMENT ON VIEW public.v_task_warnings_base IS
'Warnings W1 (PROG/ANDA após data fim), W2 (CONC SAP pendente), W3 (conflito executor), W4 (conflito frota), W5 (PROG já deveria ter iniciado).';

GRANT SELECT ON public.v_task_warnings_base TO authenticated;
GRANT SELECT ON public.v_task_warnings_base TO anon;


-- ------------------------------------------------------------------------------
-- 5. FUNÇÃO RPC: get_task_warnings_for_user (COM TIMEOUT 60s)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_task_warnings_for_user(p_user_id UUID DEFAULT NULL)
RETURNS TABLE (
  task_id UUID,
  warning_code TEXT,
  severity TEXT,
  message TEXT,
  fix_hint TEXT,
  details_json JSONB,
  created_at TIMESTAMPTZ,
  task_updated_at TIMESTAMPTZ,
  regional_id UUID,
  divisao_id UUID,
  segmento_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
SET statement_timeout = '60s'
AS $$
DECLARE
  v_uid UUID;
  v_is_root BOOLEAN;
  v_nome TEXT;
  v_has_scope BOOLEAN;
  v_executor_ids UUID[];
BEGIN
  v_uid := COALESCE(p_user_id, auth.uid());
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  v_executor_ids := ARRAY[]::UUID[];

  SELECT u.nome INTO v_nome FROM public.usuarios u WHERE u.id = v_uid;
  v_is_root := COALESCE(
    (SELECT (u.is_root = true) FROM public.usuarios u WHERE u.id = v_uid LIMIT 1),
    false
  );

  BEGIN
    SELECT COALESCE(array_agg(e.id), ARRAY[]::UUID[])
    INTO v_executor_ids
    FROM public.executores e
    INNER JOIN public.usuarios u ON u.id = v_uid
    AND (
      (e.login IS NOT NULL AND LOWER(TRIM(e.login)) = LOWER(TRIM(u.email)))
      OR (e.usuario_id = u.id)
    );
  EXCEPTION WHEN undefined_column THEN
    v_executor_ids := ARRAY[]::UUID[];
  END;
  v_executor_ids := COALESCE(v_executor_ids, ARRAY[]::UUID[]);

  SELECT
    (SELECT COUNT(*) FROM public.usuarios_regionais ur WHERE ur.usuario_id = v_uid) > 0
    OR (SELECT COUNT(*) FROM public.usuarios_divisoes ud WHERE ud.usuario_id = v_uid) > 0
    OR (SELECT COUNT(*) FROM public.usuarios_segmentos us WHERE us.usuario_id = v_uid) > 0
  INTO v_has_scope;

  RETURN QUERY
  SELECT
    w.task_id,
    w.warning_code,
    w.severity,
    w.message,
    w.fix_hint,
    w.details_json,
    w.created_at,
    w.task_updated_at,
    w.regional_id,
    w.divisao_id,
    w.segmento_id
  FROM public.v_task_warnings_base w
  WHERE
    (v_is_root)
    OR
    (v_has_scope
     AND EXISTS (SELECT 1 FROM public.usuarios_regionais ur WHERE ur.usuario_id = v_uid AND ur.regional_id = w.regional_id)
     AND EXISTS (SELECT 1 FROM public.usuarios_divisoes ud WHERE ud.usuario_id = v_uid AND ud.divisao_id = w.divisao_id)
     AND (w.segmento_id IS NULL OR EXISTS (SELECT 1 FROM public.usuarios_segmentos us WHERE us.usuario_id = v_uid AND us.segmento_id = w.segmento_id))
    )
    OR
    (NOT v_is_root AND (
      EXISTS (SELECT 1 FROM public.tasks_executores te WHERE te.task_id = w.task_id AND te.executor_id = ANY(v_executor_ids))
      OR EXISTS (SELECT 1 FROM public.executor_periods ep WHERE ep.task_id = w.task_id AND ep.executor_id = ANY(v_executor_ids))
      OR (
        v_nome IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM public.tasks t
          WHERE t.id = w.task_id AND TRIM(LOWER(COALESCE(t.coordenador, ''))) = TRIM(LOWER(v_nome))
        )
      )
    ));
END;
$$;

COMMENT ON FUNCTION public.get_task_warnings_for_user(UUID) IS
'Retorna warnings visíveis ao usuário. statement_timeout=60s. p_user_id: id da tabela usuarios (login no Flutter).';

GRANT EXECUTE ON FUNCTION public.get_task_warnings_for_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_task_warnings_for_user(UUID) TO anon;


-- ------------------------------------------------------------------------------
-- 6. ÍNDICES DE PERFORMANCE ESSENCIAIS
-- ------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_tasks_status_id ON public.tasks(status_id) WHERE status_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_status_data_fim ON public.tasks(status, data_fim);
CREATE INDEX IF NOT EXISTS idx_tasks_executores_task_executor ON public.tasks_executores(task_id, executor_id);
CREATE INDEX IF NOT EXISTS idx_executor_periods_task_executor ON public.executor_periods(task_id, executor_id);
CREATE INDEX IF NOT EXISTS idx_executor_periods_exec_task ON public.executor_periods(executor_id, task_id);
CREATE INDEX IF NOT EXISTS idx_frota_periods_frota_task ON public.frota_periods(frota_id, task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_regional_divisao_segmento ON public.tasks(regional_id, divisao_id, segmento_id) WHERE regional_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 7. RECARREGAR SCHEMA NO POSTGREST
-- ------------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
