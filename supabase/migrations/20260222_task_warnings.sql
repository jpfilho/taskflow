-- ============================================
-- TASK WARNINGS — VIEW base + RPC por usuário
-- ============================================
-- W1: Status PROG/ANDA após data final
-- W2: Status CONC com pendências SAP (notas/ordens/ATs não encerrados)
-- Estrutura preparada para adicionar W3, W4, etc.
--
-- Pré-requisitos: tasks (id, status, data_inicio, data_fim, updated_at, coordenador),
--   tasks_conc_encerramento_sap, tasks_executores, executor_periods,
--   usuarios (id, nome, is_root), usuarios_regionais, usuarios_divisoes, usuarios_segmentos.
-- Para visibilidade "executor": executores.login = usuarios.email ou executores.usuario_id.
-- ============================================

-- Garantir colunas de escopo em tasks (para filtro gerente no RPC)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'tasks' AND column_name = 'regional_id') THEN
    ALTER TABLE public.tasks ADD COLUMN regional_id UUID REFERENCES public.regionais(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'tasks' AND column_name = 'divisao_id') THEN
    ALTER TABLE public.tasks ADD COLUMN divisao_id UUID REFERENCES public.divisoes(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'tasks' AND column_name = 'segmento_id') THEN
    ALTER TABLE public.tasks ADD COLUMN segmento_id UUID REFERENCES public.segmentos(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1) VIEW BASE: v_task_warnings_base
-- Sem filtro de usuário; inclui regional_id/divisao_id/segmento_id para filtro no RPC.
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_task_warnings_base CASCADE;

CREATE VIEW public.v_task_warnings_base AS
WITH task_scope AS (
  SELECT
    t.id AS task_id,
    t.status,
    t.data_inicio,
    t.data_fim,
    t.updated_at AS task_updated_at,
    t.coordenador,
    t.regional_id,
    t.divisao_id,
    t.segmento_id
  FROM public.tasks t
),
-- ---------- Regra W1: Status atrasado/indevido ----------
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
      'hoje', CURRENT_DATE
    ) AS details_json,
    CURRENT_TIMESTAMP AS created_at,
    ts.task_updated_at,
    ts.regional_id,
    ts.divisao_id,
    ts.segmento_id
  FROM task_scope ts
  WHERE (date(ts.data_fim) < CURRENT_DATE OR (ts.data_fim IS NOT NULL AND (ts.data_fim)::date < CURRENT_DATE))
    AND UPPER(TRIM(COALESCE(ts.status, ''))) IN ('PROG', 'ANDA')
),
-- ---------- Regra W2: CONC sem SAP encerrado (reutiliza tasks_conc_encerramento_sap) ----------
w2_source AS (
  SELECT
    task_id,
    qtd_notas_nao_encerradas,
    qtd_ordens_nao_encerradas,
    qtd_ats_nao_encerradas
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
-- União de todas as regras (adicionar novas aqui: W3, W4, ...)
all_warnings AS (
  SELECT task_id, warning_code, severity, message, fix_hint, details_json, created_at, task_updated_at, regional_id, divisao_id, segmento_id FROM w1_candidates
  UNION ALL
  SELECT task_id, warning_code, severity, message, fix_hint, details_json, created_at, task_updated_at, regional_id, divisao_id, segmento_id FROM w2_candidates
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
'Warnings de tarefas (W1: atraso status, W2: CONC com SAP pendente). Base sem filtro de usuário; usar get_task_warnings_for_user() para visibilidade.';

GRANT SELECT ON public.v_task_warnings_base TO authenticated;
GRANT SELECT ON public.v_task_warnings_base TO anon;


-- ---------------------------------------------------------------------------
-- 2) FUNÇÃO: get_task_warnings_for_user()
-- Retorna o mesmo shape da view base, filtrado por auth.uid().
-- - Root (usuarios.is_root): todos
-- - Gerente (tem regionais/divisões/segmentos no perfil): escopo regional+divisão+segmento
-- - Demais: apenas tarefas em que o usuário é executor vinculado ou coordenador
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_task_warnings_for_user()
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
AS $$
DECLARE
  v_uid UUID;
  v_is_root BOOLEAN;
  v_nome TEXT;
  v_has_scope BOOLEAN;
  v_regionals UUID[];
  v_divisoes UUID[];
  v_segmentos UUID[];
  v_executor_ids UUID[];
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  v_executor_ids := ARRAY[]::UUID[];

  -- Dados do usuário (usuarios pode ter is_root; se não existir coluna, assume false)
  SELECT u.nome INTO v_nome FROM public.usuarios u WHERE u.id = v_uid;
  v_is_root := COALESCE(
    (SELECT (u.is_root = true) FROM public.usuarios u WHERE u.id = v_uid LIMIT 1),
    false
  );

  -- Executor(es) vinculados ao usuário: por login = email (se executores.login existir) ou usuario_id
  -- Se não houver coluna executores.login/usuario_id, array fica vazio e visibilidade "executor" não retorna nada
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

  -- Escopo gerente: usuário tem pelo menos um regional/divisão/segmento no perfil
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
    -- Root: vê tudo
    (v_is_root)
    OR
    -- Gerente: tarefa no escopo (task.regional_id/divisao_id/segmento_id no perfil do usuário)
    (v_has_scope
     AND EXISTS (SELECT 1 FROM public.usuarios_regionais ur WHERE ur.usuario_id = v_uid AND ur.regional_id = w.regional_id)
     AND EXISTS (SELECT 1 FROM public.usuarios_divisoes ud WHERE ud.usuario_id = v_uid AND ud.divisao_id = w.divisao_id)
     AND (w.segmento_id IS NULL OR EXISTS (SELECT 1 FROM public.usuarios_segmentos us WHERE us.usuario_id = v_uid AND us.segmento_id = w.segmento_id))
    )
    OR
    -- Executor ou coordenador: tarefa onde o usuário está vinculado
    (NOT v_is_root AND (
      EXISTS (
        SELECT 1 FROM public.tasks_executores te
        WHERE te.task_id = w.task_id AND te.executor_id = ANY(v_executor_ids)
      )
      OR EXISTS (
        SELECT 1 FROM public.executor_periods ep
        WHERE ep.task_id = w.task_id AND ep.executor_id = ANY(v_executor_ids)
      )
      OR (
        v_nome IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM public.tasks t
          WHERE t.id = w.task_id
          AND TRIM(LOWER(COALESCE(t.coordenador, ''))) = TRIM(LOWER(v_nome))
        )
      )
    ));
END;
$$;

COMMENT ON FUNCTION public.get_task_warnings_for_user() IS
'Retorna warnings de tarefas visíveis ao usuário logado (auth.uid()): root= todos; gerente= escopo regional/divisão/segmento; demais= executor ou coordenador vinculado.';

GRANT EXECUTE ON FUNCTION public.get_task_warnings_for_user() TO authenticated;


-- ---------------------------------------------------------------------------
-- 3) Índices recomendados (se não existirem)
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_data_fim ON public.tasks(data_fim);
CREATE INDEX IF NOT EXISTS idx_tasks_regional_id ON public.tasks(regional_id);
CREATE INDEX IF NOT EXISTS idx_tasks_divisao_id ON public.tasks(divisao_id);
CREATE INDEX IF NOT EXISTS idx_tasks_segmento_id ON public.tasks(segmento_id);
CREATE INDEX IF NOT EXISTS idx_tasks_executores_executor_id ON public.tasks_executores(executor_id);
CREATE INDEX IF NOT EXISTS idx_executor_periods_task_id ON public.executor_periods(task_id);

NOTIFY pgrst, 'reload schema';


-- ============================================
-- VALIDAÇÃO E EXEMPLOS DE CONSULTA
-- ============================================
-- Executar no SQL Editor para testar:
--
-- 1) Ver todos os warnings (base, sem filtro de usuário):
--    SELECT * FROM public.v_task_warnings_base ORDER BY severity DESC, task_id LIMIT 50;
--
-- 2) Warnings visíveis para o usuário logado (requer auth):
--    SELECT * FROM public.get_task_warnings_for_user() ORDER BY severity DESC, task_id LIMIT 50;
--
-- 3) Testes sugeridos:
--    a) Tarefa atrasada em PROG/ANDA: criar/ajustar uma task com data_fim < CURRENT_DATE e status PROG ou ANDA; deve aparecer W1.
--    b) Tarefa CONC com SAP pendente: tarefa CONC com nota/ordem/AT vinculado e status_sistema sem ENTE/ENCE/MSEN; deve aparecer W2.
--    c) Usuário executor: logar com usuário cujo email = executores.login (ou vinculado por usuario_id); deve ver apenas warnings das tarefas em que é executor ou coordenador.
--    d) Gerente: usuário com registros em usuarios_regionais, usuarios_divisoes, usuarios_segmentos; deve ver warnings das tarefas cujo (regional_id, divisao_id, segmento_id) batem com o perfil.
--
-- 4) Adicionar nova regra (ex.: W3): em v_task_warnings_base, criar w3_candidates (SELECT ...) e adicionar na UNION ALL de all_warnings:
--    UNION ALL
--    SELECT ... FROM w3_candidates
