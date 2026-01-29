-- ============================================
-- VIEW: v_execucoes_dia_frota
-- ============================================
-- Execuções por dia por FROTA (equivalente à v_execucoes_dia_completa para executores).
-- Inclui EXECUCAO e DESLOCAMENTO. Períodos do tipo PLANEJAMENTO são DESCONSIDERADOS.
-- CANC (cancelados) e REPR (reprogramados) são DESCONSIDERADOS.
-- ============================================

DROP VIEW IF EXISTS public.v_execucoes_dia_frota CASCADE;

CREATE VIEW public.v_execucoes_dia_frota AS
WITH
  -- Status a desconsiderar
  status_excluidos AS (
    SELECT unnest(ARRAY['CANC'::text, 'REPR'::text]) AS codigo
  ),

  -- Locais das tarefas
  locs AS (
    SELECT
      t.id AS task_id,
      COALESCE(l.local, t.local, ''::character varying) AS local_nome,
      COALESCE(l.id::text, t.local_id::text, ''::text) AS loc_key
    FROM tasks t
    LEFT JOIN locais l ON l.id = t.local_id
  ),

  -- Períodos de frota_periods (EXECUCAO)
  fp_execucao AS (
    SELECT
      fp.frota_id,
      COALESCE(f.nome || ' - ' || f.placa, fp.frota_nome, ''::text) AS frota_nome,
      fp.task_id,
      g.day::date AS day,
      t.status AS task_status,
      t.tipo AS task_tipo,
      t.tarefa AS task_tarefa,
      COALESCE(l.local_nome, ''::character varying) AS local_nome,
      COALESCE(l.loc_key, ''::text) AS loc_key,
      'EXECUCAO'::text AS tipo_periodo,
      fp.data_inicio AS periodo_inicio,
      fp.data_fim AS periodo_fim
    FROM frota_periods fp
    JOIN tasks t ON t.id = fp.task_id
    LEFT JOIN frota f ON f.id = fp.frota_id
    LEFT JOIN locs l ON l.task_id = fp.task_id
    CROSS JOIN LATERAL generate_series(
      date(fp.data_inicio)::timestamp with time zone,
      date(fp.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(COALESCE(fp.tipo_periodo, ''::text)) = 'EXECUCAO'
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN (SELECT codigo FROM status_excluidos)
  ),

  -- Períodos de frota_periods (apenas DESLOCAMENTO; PLANEJAMENTO desconsiderado)
  fp_deslocamento AS (
    SELECT
      fp.frota_id,
      COALESCE(f.nome || ' - ' || f.placa, fp.frota_nome, ''::text) AS frota_nome,
      fp.task_id,
      g.day::date AS day,
      t.status AS task_status,
      t.tipo AS task_tipo,
      t.tarefa AS task_tarefa,
      COALESCE(l.local_nome, ''::character varying) AS local_nome,
      COALESCE(l.loc_key, ''::text) AS loc_key,
      'DESLOCAMENTO'::text AS tipo_periodo,
      fp.data_inicio AS periodo_inicio,
      fp.data_fim AS periodo_fim
    FROM frota_periods fp
    JOIN tasks t ON t.id = fp.task_id
    LEFT JOIN frota f ON f.id = fp.frota_id
    LEFT JOIN locs l ON l.task_id = fp.task_id
    CROSS JOIN LATERAL generate_series(
      date(fp.data_inicio)::timestamp with time zone,
      date(fp.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(COALESCE(fp.tipo_periodo, ''::text)) = 'DESLOCAMENTO'
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN (SELECT codigo FROM status_excluidos)
  ),

  -- Períodos de gantt_segments quando a tarefa tem tasks_frotas mas não tem frota_periods para essa frota
  gs_execucao AS (
    SELECT
      tf.frota_id,
      COALESCE(f.nome || ' - ' || f.placa, f.nome, ''::text) AS frota_nome,
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
    FROM tasks t
    JOIN tasks_frotas tf ON tf.task_id = t.id
    JOIN frota f ON f.id = tf.frota_id
    LEFT JOIN locs l ON l.task_id = t.id
    JOIN gantt_segments gs ON gs.task_id = t.id
    CROSS JOIN LATERAL generate_series(
      date(gs.data_inicio)::timestamp with time zone,
      date(gs.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(COALESCE(gs.tipo_periodo, ''::text)) = 'EXECUCAO'
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN (SELECT codigo FROM status_excluidos)
      AND NOT EXISTS (
        SELECT 1 FROM frota_periods fp
        WHERE fp.task_id = t.id AND fp.frota_id = tf.frota_id
      )
  ),

  -- Apenas DESLOCAMENTO de gantt_segments; PLANEJAMENTO desconsiderado
  gs_deslocamento AS (
    SELECT
      tf.frota_id,
      COALESCE(f.nome || ' - ' || f.placa, f.nome, ''::text) AS frota_nome,
      t.id AS task_id,
      g.day::date AS day,
      t.status AS task_status,
      t.tipo AS task_tipo,
      t.tarefa AS task_tarefa,
      COALESCE(l.local_nome, ''::character varying) AS local_nome,
      COALESCE(l.loc_key, ''::text) AS loc_key,
      'DESLOCAMENTO'::text AS tipo_periodo,
      gs.data_inicio AS periodo_inicio,
      gs.data_fim AS periodo_fim
    FROM tasks t
    JOIN tasks_frotas tf ON tf.task_id = t.id
    JOIN frota f ON f.id = tf.frota_id
    LEFT JOIN locs l ON l.task_id = t.id
    JOIN gantt_segments gs ON gs.task_id = t.id
    CROSS JOIN LATERAL generate_series(
      date(gs.data_inicio)::timestamp with time zone,
      date(gs.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE UPPER(COALESCE(gs.tipo_periodo, ''::text)) = 'DESLOCAMENTO'
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN (SELECT codigo FROM status_excluidos)
      AND NOT EXISTS (
        SELECT 1 FROM frota_periods fp
        WHERE fp.task_id = t.id AND fp.frota_id = tf.frota_id
      )
  ),

  -- Fallback: datas gerais da tarefa quando não há segmentos nem frota_periods
  task_base AS (
    SELECT
      tf.frota_id,
      COALESCE(f.nome || ' - ' || f.placa, f.nome, ''::text) AS frota_nome,
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
    FROM tasks t
    JOIN tasks_frotas tf ON tf.task_id = t.id
    JOIN frota f ON f.id = tf.frota_id
    LEFT JOIN locs l ON l.task_id = t.id
    CROSS JOIN LATERAL generate_series(
      date(t.data_inicio)::timestamp with time zone,
      date(t.data_fim)::timestamp with time zone,
      '1 day'::interval
    ) g(day)
    WHERE t.data_inicio IS NOT NULL
      AND t.data_fim IS NOT NULL
      AND UPPER(TRIM(COALESCE(t.status, ''))) NOT IN (SELECT codigo FROM status_excluidos)
      AND NOT EXISTS (SELECT 1 FROM frota_periods fp WHERE fp.task_id = t.id AND fp.frota_id = tf.frota_id)
      AND NOT EXISTS (SELECT 1 FROM gantt_segments gs WHERE gs.task_id = t.id)
  ),

  unioned AS (
    SELECT frota_id, frota_nome, task_id, day, task_status, task_tipo, task_tarefa,
           local_nome, loc_key, tipo_periodo, periodo_inicio, periodo_fim FROM fp_execucao
    UNION ALL
    SELECT frota_id, frota_nome, task_id, day, task_status, task_tipo, task_tarefa,
           local_nome, loc_key, tipo_periodo, periodo_inicio, periodo_fim FROM fp_deslocamento
    UNION ALL
    SELECT frota_id, frota_nome, task_id, day, task_status, task_tipo, task_tarefa,
           local_nome, loc_key, tipo_periodo, periodo_inicio, periodo_fim FROM gs_execucao
    UNION ALL
    SELECT frota_id, frota_nome, task_id, day, task_status, task_tipo, task_tarefa,
           local_nome, loc_key, tipo_periodo, periodo_inicio, periodo_fim FROM gs_deslocamento
    UNION ALL
    SELECT frota_id, frota_nome, task_id, day, task_status, task_tipo, task_tarefa,
           local_nome, loc_key, tipo_periodo, periodo_inicio, periodo_fim FROM task_base
  ),

  -- Conflito: múltiplos locais no mesmo dia por frota (apenas EXECUCAO)
  loc_count AS (
    SELECT
      unioned.frota_id,
      unioned.day,
      COUNT(DISTINCT NULLIF(COALESCE(NULLIF(unioned.loc_key, ''), '__LOCNAME__' || unioned.local_nome), '')) AS locs_distintos
    FROM unioned
    WHERE UPPER(unioned.tipo_periodo) = 'EXECUCAO'
    GROUP BY unioned.frota_id, unioned.day
  ),

  flagged AS (
    SELECT
      u.frota_id,
      u.frota_nome,
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
      COALESCE(lc.locs_distintos, 0) > 1 AS has_conflict
    FROM unioned u
    LEFT JOIN loc_count lc ON lc.frota_id = u.frota_id AND lc.day = u.day
  )
SELECT
  flagged.frota_id,
  flagged.frota_nome,
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

COMMENT ON VIEW public.v_execucoes_dia_frota IS
'Execuções por dia por frota. Inclui EXECUCAO e DESLOCAMENTO; exclui PLANEJAMENTO, CANC e REPR. Usado pela tela de Frota.';
