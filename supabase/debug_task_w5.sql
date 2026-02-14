-- ============================================
-- DEBUG: por que uma tarefa aparece no W5?
-- ============================================
-- Se o SELECT abaixo retornar "No rows": rode primeiro o "Passo 0" para listar tarefas
-- e ver como id/tarefa/status estão gravados; depois ajuste o WHERE (tarefa LIKE ou id).
-- ============================================

-- ---------- Passo 0: listar tarefas para achar a certa (rode isto se o filtro não achar nada) ----------
-- Últimas tarefas atualizadas (veja id, tarefa, status e use no WHERE do SELECT principal)
SELECT id, LEFT(tarefa, 55) AS tarefa, status, status_id, data_inicio::date, data_fim::date, updated_at
FROM public.tasks
ORDER BY updated_at DESC NULLS LAST
LIMIT 15;

-- ---------- Passo 1: DO block com RAISE NOTICE (mensagens na aba Messages) ----------

DO $$
DECLARE
  p_task_id UUID := NULL;           -- Ex.: 'a1b2c3d4-...'::UUID ou NULL para buscar por nome
  p_tarefa_like TEXT := '%11438987%'; -- Ex.: '%11438987%' ou '%NM 11438987%'
  v_tasks RECORD;
  v_today_br DATE;
  v_status_codigo TEXT;
  v_w5_entraria BOOLEAN;
BEGIN
  v_today_br := (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date;

  RAISE NOTICE '=== DEBUG W5 ===';
  RAISE NOTICE 'Hoje (Brasil): %', v_today_br;

  FOR v_tasks IN
    SELECT t.id, t.tarefa, t.status, t.status_id, t.data_inicio, t.data_fim
    FROM public.tasks t
    WHERE (p_task_id IS NOT NULL AND t.id = p_task_id)
       OR (p_task_id IS NULL AND p_tarefa_like IS NOT NULL AND t.tarefa LIKE p_tarefa_like)
    LIMIT 5
  LOOP
    RAISE NOTICE '---';
    RAISE NOTICE 'task.id: %', v_tasks.id;
    RAISE NOTICE 'task.tarefa: %', LEFT(v_tasks.tarefa, 60);
    RAISE NOTICE 'task.status: %', v_tasks.status;
    RAISE NOTICE 'task.status_id: %', v_tasks.status_id;
    RAISE NOTICE 'task.data_inicio: %', v_tasks.data_inicio;
    RAISE NOTICE 'task.data_fim: %', v_tasks.data_fim;

    -- Código do status na tabela status (se existir)
    BEGIN
      SELECT st.codigo INTO v_status_codigo
      FROM public.status st
      WHERE st.id = v_tasks.status_id;
      RAISE NOTICE 'status.codigo (por status_id): %', COALESCE(v_status_codigo, '(não encontrado ou tabela status inexistente)');
    EXCEPTION WHEN undefined_table THEN
      RAISE NOTICE 'status.codigo: (tabela public.status não existe)';
      v_status_codigo := NULL;
    END;

    -- Entraria no W5? (lógica da view)
    v_w5_entraria := (
      UPPER(TRIM(COALESCE(v_tasks.status, ''))) = 'PROG'
      AND UPPER(TRIM(COALESCE(v_tasks.status, ''))) NOT IN ('RPGR', 'REPR')
      AND (v_tasks.data_inicio IS NOT NULL AND (v_tasks.data_inicio)::date <= v_today_br)
      AND (v_tasks.data_fim IS NULL OR (v_tasks.data_fim)::date >= v_today_br)
      AND (v_status_codigo IS NULL OR UPPER(TRIM(v_status_codigo)) <> 'RPGR')
    );
    RAISE NOTICE 'Entraria no W5? %', v_w5_entraria;
  END LOOP;

  RAISE NOTICE '=== FIM DEBUG ===';
END $$;

-- ---------- Passo 2: SELECT com motivo_w5 (ajuste o WHERE: use id ou tarefa LIKE) ----------
-- Se "No rows returned": rode só o Passo 0 acima, copie o id ou o texto de tarefa e use aqui.
SELECT
  t.id,
  LEFT(t.tarefa, 50) AS tarefa,
  t.status AS task_status,
  t.status_id,
  st.codigo AS status_codigo,
  t.data_inicio::date,
  t.data_fim::date,
  (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date AS hoje_br,
  (t.data_inicio)::date <= (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date AS inicio_ja_passou,
  (t.data_fim IS NULL OR (t.data_fim)::date >= (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date) AS ainda_no_prazo,
  CASE
    WHEN UPPER(TRIM(COALESCE(t.status, ''))) <> 'PROG' THEN 'não: status <> PROG'
    WHEN UPPER(TRIM(COALESCE(t.status, ''))) IN ('RPGR', 'REPR') THEN 'não: status é RPGR/REPR'
    WHEN EXISTS (SELECT 1 FROM public.status st2 WHERE st2.id = t.status_id AND UPPER(TRIM(st2.codigo)) = 'RPGR') THEN 'não: status_id é RPGR'
    WHEN t.data_inicio IS NULL THEN 'não: data_inicio null'
    WHEN (t.data_inicio)::date > (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date THEN 'não: início no futuro'
    WHEN t.data_fim IS NOT NULL AND (t.data_fim)::date < (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date THEN 'não: já passou data_fim (W1)'
    ELSE 'SIM → aparece W5'
  END AS motivo_w5
FROM public.tasks t
LEFT JOIN public.status st ON st.id = t.status_id
WHERE t.tarefa LIKE '%11438987%'   -- ou: t.id = 'uuid-aqui'::uuid
LIMIT 5;

-- ---------- Passo 3: sincronização de tasks.status ----------
-- Já existe a migration 20260226_sync_tasks_status_from_status_table.sql.
-- Se precisar rodar de novo manualmente, use o UPDATE dessa migration.
