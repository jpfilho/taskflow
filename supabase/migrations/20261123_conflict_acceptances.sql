-- Migration: Aceite de Conflitos (Executor e Frota) entre pares de tarefas
-- Permite aceitar um conflito específico para um executor ou frota entre duas tarefas,
-- suprimindo o conflito apenas para aquele par (outras tarefas/recursos continuam alertando).

-- 1. Tabela de aceites de conflito
CREATE TABLE IF NOT EXISTS public.conflict_acceptances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_type text NOT NULL CHECK (resource_type IN ('EXECUTOR', 'FROTA')),
  resource_id text NOT NULL,
  resource_nome text,
  task_id_a text NOT NULL,
  task_id_b text NOT NULL,
  reason text,
  accepted_by uuid,
  accepted_by_name text,
  accepted_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  revoked_by uuid,
  CONSTRAINT conflict_acceptances_pair_order CHECK (task_id_a < task_id_b)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_conflict_acceptances_active_pair
  ON public.conflict_acceptances (resource_type, lower(resource_id), task_id_a, task_id_b)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_conflict_acceptances_active_tasks
  ON public.conflict_acceptances (task_id_a, task_id_b)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_conflict_acceptances_active_resource
  ON public.conflict_acceptances (resource_type, lower(resource_id))
  WHERE revoked_at IS NULL;

ALTER TABLE public.conflict_acceptances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conflict_acceptances_select_authenticated" ON public.conflict_acceptances;
CREATE POLICY "conflict_acceptances_select_authenticated"
  ON public.conflict_acceptances
  FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "conflict_acceptances_insert_authenticated" ON public.conflict_acceptances;
CREATE POLICY "conflict_acceptances_insert_authenticated"
  ON public.conflict_acceptances
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    NULLIF(TRIM(resource_id), '') IS NOT NULL
    AND NULLIF(TRIM(task_id_a), '') IS NOT NULL
    AND NULLIF(TRIM(task_id_b), '') IS NOT NULL
    AND task_id_a < task_id_b
  );

DROP POLICY IF EXISTS "conflict_acceptances_update_authenticated" ON public.conflict_acceptances;
CREATE POLICY "conflict_acceptances_update_authenticated"
  ON public.conflict_acceptances
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE ON public.conflict_acceptances TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.conflict_acceptances TO anon;

-- 2. Atualizar v_conflict_por_dia_executor preservando assinatura exata (CREATE OR REPLACE VIEW)
CREATE OR REPLACE VIEW public.v_conflict_por_dia_executor AS
WITH ev AS (
  SELECT executor_id, executor_nome, day, location_key, task_id, description
  FROM public.v_conflict_execution_events
),
unaccepted_pairs AS (
  SELECT DISTINCT
    e1.executor_id,
    e1.day,
    e1.task_id AS task_1,
    e2.task_id AS task_2
  FROM ev e1
  JOIN ev e2
    ON e1.executor_id = e2.executor_id
   AND e1.day = e2.day
   AND e1.task_id < e2.task_id
   AND NULLIF(TRIM(e1.location_key), '') IS NOT NULL
   AND NULLIF(TRIM(e2.location_key), '') IS NOT NULL
   AND NULLIF(TRIM(e1.location_key), '') <> NULLIF(TRIM(e2.location_key), '')
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.conflict_acceptances ca
    WHERE ca.revoked_at IS NULL
      AND ca.resource_type = 'EXECUTOR'
      AND lower(ca.resource_id) = lower(e1.executor_id::text)
      AND ca.task_id_a = LEAST(e1.task_id::text, e2.task_id::text)
      AND ca.task_id_b = GREATEST(e1.task_id::text, e2.task_id::text)
  )
),
unaccepted_tasks AS (
  SELECT executor_id, day, task_1 AS task_id FROM unaccepted_pairs
  UNION
  SELECT executor_id, day, task_2 AS task_id FROM unaccepted_pairs
),
has_conf AS (
  SELECT DISTINCT executor_id, day
  FROM unaccepted_pairs
)
SELECT
  ev.executor_id,
  ev.executor_nome,
  ev.day,
  (hc.executor_id IS NOT NULL) AS has_conflict,
  COALESCE(
    array_agg(DISTINCT ev.description ORDER BY ev.description)
      FILTER (
        WHERE ut.task_id IS NOT NULL
          AND ev.description IS NOT NULL
          AND ev.description != ''
      ),
    ARRAY[]::text[]
  ) AS descriptions
FROM ev
LEFT JOIN has_conf hc
  ON hc.executor_id = ev.executor_id
 AND hc.day = ev.day
LEFT JOIN unaccepted_tasks ut
  ON ut.executor_id = ev.executor_id
 AND ut.day = ev.day
 AND ut.task_id = ev.task_id
GROUP BY ev.executor_id, ev.executor_nome, ev.day, hc.executor_id;

-- 3. Atualizar v_conflict_por_dia_frota preservando assinatura exata (CREATE OR REPLACE VIEW)
CREATE OR REPLACE VIEW public.v_conflict_por_dia_frota AS
WITH ev AS (
  SELECT frota_id, frota_nome, day, location_key, task_id, description
  FROM public.v_conflict_execution_events_frota
),
unaccepted_pairs AS (
  SELECT DISTINCT
    e1.frota_id,
    e1.day,
    e1.task_id AS task_1,
    e2.task_id AS task_2
  FROM ev e1
  JOIN ev e2
    ON e1.frota_id = e2.frota_id
   AND e1.day = e2.day
   AND e1.task_id < e2.task_id
   AND NULLIF(TRIM(e1.location_key), '') IS NOT NULL
   AND NULLIF(TRIM(e2.location_key), '') IS NOT NULL
   AND NULLIF(TRIM(e1.location_key), '') <> NULLIF(TRIM(e2.location_key), '')
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.conflict_acceptances ca
    WHERE ca.revoked_at IS NULL
      AND ca.resource_type = 'FROTA'
      AND lower(ca.resource_id) = lower(e1.frota_id::text)
      AND ca.task_id_a = LEAST(e1.task_id::text, e2.task_id::text)
      AND ca.task_id_b = GREATEST(e1.task_id::text, e2.task_id::text)
  )
),
unaccepted_tasks AS (
  SELECT frota_id, day, task_1 AS task_id FROM unaccepted_pairs
  UNION
  SELECT frota_id, day, task_2 AS task_id FROM unaccepted_pairs
),
has_conf AS (
  SELECT DISTINCT frota_id, day
  FROM unaccepted_pairs
)
SELECT
  ev.frota_id,
  ev.frota_nome,
  ev.day,
  (hc.frota_id IS NOT NULL) AS has_conflict,
  COALESCE(
    array_agg(DISTINCT ev.description ORDER BY ev.description)
      FILTER (
        WHERE ut.task_id IS NOT NULL
          AND ev.description IS NOT NULL
          AND ev.description != ''
      ),
    ARRAY[]::text[]
  ) AS descriptions
FROM ev
LEFT JOIN has_conf hc
  ON hc.frota_id = ev.frota_id
 AND hc.day = ev.day
LEFT JOIN unaccepted_tasks ut
  ON ut.frota_id = ev.frota_id
 AND ut.day = ev.day
 AND ut.task_id = ev.task_id
GROUP BY ev.frota_id, ev.frota_nome, ev.day, hc.frota_id;

