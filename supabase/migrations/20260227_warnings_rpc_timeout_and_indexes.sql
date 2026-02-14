-- ============================================
-- Evitar timeout na RPC get_task_warnings_for_user
-- ============================================
-- A view v_task_warnings_base (W1–W5) + filtro por usuário pode demorar;
-- aumentamos o timeout da função e adicionamos índices úteis.
-- ============================================

-- 1) Aumentar timeout da RPC para 60s (padrão Supabase costuma ser ~8s)
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

-- 2) Índices para a view e para o filtro da RPC
CREATE INDEX IF NOT EXISTS idx_tasks_status_id ON public.tasks(status_id) WHERE status_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_executores_task_executor ON public.tasks_executores(task_id, executor_id);
CREATE INDEX IF NOT EXISTS idx_executor_periods_task_executor ON public.executor_periods(task_id, executor_id);
CREATE INDEX IF NOT EXISTS idx_tasks_regional_divisao_segmento ON public.tasks(regional_id, divisao_id, segmento_id) WHERE regional_id IS NOT NULL;

COMMENT ON FUNCTION public.get_task_warnings_for_user(UUID) IS
'Retorna warnings visíveis ao usuário. statement_timeout=60s. p_user_id: id da tabela usuarios (login no Flutter).';
