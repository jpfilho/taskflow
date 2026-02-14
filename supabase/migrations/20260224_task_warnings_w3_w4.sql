-- ============================================
-- TASK WARNINGS W3, W4 e W5 — Conflitos + Programado sem iniciar
-- ============================================
-- W3: Conflito de Executor
-- W4: Conflito de Frota
-- W5: Programado mas já deveria ter iniciado (PROG com data_inicio no passado, sem passar data_fim; não duplica W1)
--
-- Reutiliza: v_conflict_* (executor/frota). RPC get_task_warnings_for_user(p_user_id) filtra por usuário.
-- ============================================

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
-- Data "hoje" no fuso do Brasil (America/Sao_Paulo) para W1 e W5 não dependerem de UTC.
today_br AS (
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date AS d
),
-- ---------- W1: Status PROG/ANDA após data final ----------
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
-- ---------- W2: CONC com pendência SAP ----------
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
-- ---------- W3: Conflito de Executor (uma linha por tarefa; sem IDs nos textos) ----------
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
-- ---------- W4: Conflito de Frota (uma linha por tarefa; sem IDs nos textos) ----------
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
-- ---------- W5: Programado mas já deveria ter iniciado (MEDIUM); não duplica W1 ----------
-- Apenas status PROG (Programado). RPGR (Reprogramado) nunca recebe W5: excluir por texto e por status_id.
-- Usa today_br (já definido acima) para não mostrar W5 antes da meia-noite no Brasil.
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
'Warnings W1 (PROG/ANDA após data fim), W2 (CONC SAP pendente), W3 (conflito executor), W4 (conflito frota), W5 (PROG já deveria ter iniciado). Usar get_task_warnings_for_user(p_user_id) para visibilidade.';

GRANT SELECT ON public.v_task_warnings_base TO authenticated;
GRANT SELECT ON public.v_task_warnings_base TO anon;

-- Índices recomendados (se ainda não existirem)
CREATE INDEX IF NOT EXISTS idx_tasks_status_data_fim ON public.tasks(status, data_fim);
CREATE INDEX IF NOT EXISTS idx_gantt_segments_task_period ON public.gantt_segments(task_id, data_inicio, data_fim) WHERE UPPER(TRIM(COALESCE(tipo_periodo, ''))) = 'EXECUCAO';
CREATE INDEX IF NOT EXISTS idx_executor_periods_exec_task ON public.executor_periods(executor_id, task_id);
CREATE INDEX IF NOT EXISTS idx_frota_periods_frota_task ON public.frota_periods(frota_id, task_id);

NOTIFY pgrst, 'reload schema';

-- ============================================
-- Exemplos de consulta e testes rápidos
-- ============================================
-- 1) Apenas conflitos (W3, W4):
--    SELECT * FROM public.v_task_warnings_base WHERE warning_code IN ('W3','W4') ORDER BY task_updated_at DESC NULLS LAST LIMIT 50;
--
-- 2) Apenas W5 (programado sem iniciar):
--    SELECT * FROM public.v_task_warnings_base WHERE warning_code = 'W5' ORDER BY task_updated_at DESC NULLS LAST LIMIT 50;
--
-- 3) Por severidade (HIGH primeiro, depois MEDIUM):
--    SELECT * FROM public.v_task_warnings_base ORDER BY CASE severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, task_id LIMIT 50;
--
-- 4) Warnings visíveis ao usuário (Flutter envia p_user_id da tabela usuarios):
--    SELECT * FROM public.get_task_warnings_for_user(p_user_id := 'uuid-do-usuario') ORDER BY severity DESC, task_id LIMIT 50;
--    -- Ou sem parâmetro (usa auth.uid()): SELECT * FROM public.get_task_warnings_for_user() LIMIT 50;
