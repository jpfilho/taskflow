-- ============================================================================
-- TASKFLOW — FASE 7: REVISÃO DE MONITORAMENTO (TABELAS RELACIONAIS +
-- IDEMPOTÊNCIA SEM COLISÃO TEMPORAL) E SUPORTE A INDICADORES GERENCIAIS
-- Ambiente: DEV ONLY
-- ============================================================================

BEGIN;

-- 1. Atualizar fn_monitorar_alteracao_task_apoio para usar txid_current() + md5
--    evitando que duas alterações legítimas em curto intervalo (<1s) colidam.
CREATE OR REPLACE FUNCTION public.fn_monitorar_alteracao_task_apoio()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mudou_periodo BOOLEAN := FALSE;
  v_mudou_recurso BOOLEAN := FALSE;
  v_mudou_status BOOLEAN := FALSE;
  v_evento TEXT;
  v_vinc RECORD;
  v_sol RECORD;
  v_idem TEXT;
  v_tx_tag TEXT;
BEGIN
  v_tx_tag := txid_current()::text || ':' || md5(clock_timestamp()::text || random()::text);

  IF TG_OP = 'DELETE' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tasks_apoios_vinculos v
      WHERE v.ativo = TRUE AND (v.task_principal_id = OLD.id OR v.task_apoio_id = OLD.id)
    ) AND NOT EXISTS (
      SELECT 1 FROM public.tasks_apoios_solicitacoes s
      WHERE s.ativo = TRUE AND s.task_solicitante_id = OLD.id AND s.status NOT IN ('CANCELADA', 'RECUSADA')
    ) THEN
      RETURN OLD;
    END IF;
    v_evento := 'ATIVIDADE_EXCLUIDA';

    FOR v_vinc IN
      SELECT DISTINCT v.solicitacao_id, v.task_principal_id, v.task_apoio_id
      FROM public.tasks_apoios_vinculos v
      WHERE v.ativo = TRUE AND (v.task_principal_id = OLD.id OR v.task_apoio_id = OLD.id)
    LOOP
      v_idem := 'TASK_DEL:' || OLD.id::text || ':' || COALESCE(v_vinc.solicitacao_id::text, 'SEM_SOL') || ':' || v_tx_tag;
      INSERT INTO public.notificacoes_eventos_outbox (
        modulo, evento_tipo, entidade_tipo, entidade_id, solicitacao_id, task_id, payload_json, idempotency_key
      ) VALUES (
        'APOIOS_OPERACIONAIS', v_evento, 'TASK', OLD.id, v_vinc.solicitacao_id, OLD.id,
        jsonb_build_object(
          'task_id', OLD.id,
          'tarefa', OLD.tarefa,
          'papel_task', CASE WHEN v_vinc.task_principal_id = OLD.id THEN 'PRINCIPAL' ELSE 'APOIO' END
        ),
        v_idem
      ) ON CONFLICT (idempotency_key) DO NOTHING;
    END LOOP;

    RETURN OLD;
  END IF;

  v_mudou_periodo := (NEW.data_inicio IS DISTINCT FROM OLD.data_inicio) OR (NEW.data_fim IS DISTINCT FROM OLD.data_fim);
  v_mudou_recurso := (NEW.frota IS DISTINCT FROM OLD.frota)
    OR (NEW.executor IS DISTINCT FROM OLD.executor)
    OR (NEW.equipe_id IS DISTINCT FROM OLD.equipe_id);
  v_mudou_status := (NEW.status IS DISTINCT FROM OLD.status);

  IF NOT (v_mudou_periodo OR v_mudou_recurso OR v_mudou_status) THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.tasks_apoios_vinculos v
    WHERE v.ativo = TRUE AND (v.task_principal_id = NEW.id OR v.task_apoio_id = NEW.id)
  ) AND NOT EXISTS (
    SELECT 1 FROM public.tasks_apoios_solicitacoes s
    WHERE s.ativo = TRUE AND s.task_solicitante_id = NEW.id AND s.status NOT IN ('CANCELADA', 'RECUSADA')
  ) THEN
    RETURN NEW;
  END IF;

  IF v_mudou_status AND UPPER(COALESCE(NEW.status, '')) IN ('CANC', 'CANCELADA') THEN
    v_evento := 'ATIVIDADE_CANCELADA';
  ELSIF v_mudou_status AND UPPER(COALESCE(NEW.status, '')) IN ('CONC', 'CONCLUIDA') THEN
    v_evento := 'APOIO_CONCLUIDO';
  ELSIF v_mudou_status AND UPPER(COALESCE(NEW.status, '')) IN ('ANDA', 'EM_ANDAMENTO') THEN
    v_evento := 'APOIO_INICIADO';
  ELSIF v_mudou_periodo THEN
    v_evento := 'ATIVIDADE_REPROGRAMADA';
  ELSE
    v_evento := 'RECURSO_ATIVIDADE_ALTERADO';
  END IF;

  FOR v_vinc IN
    SELECT DISTINCT v.id AS vinculo_id, v.solicitacao_id, v.task_principal_id, v.task_apoio_id
    FROM public.tasks_apoios_vinculos v
    WHERE v.ativo = TRUE AND (v.task_principal_id = NEW.id OR v.task_apoio_id = NEW.id)
  LOOP
    v_idem := 'TASK_UPD:' || NEW.id::text || ':' || v_evento || ':' || COALESCE(v_vinc.solicitacao_id::text, v_vinc.vinculo_id::text) || ':' || v_tx_tag;
    INSERT INTO public.notificacoes_eventos_outbox (
      modulo, evento_tipo, entidade_tipo, entidade_id, solicitacao_id, task_id, payload_json, idempotency_key
    ) VALUES (
      'APOIOS_OPERACIONAIS',
      v_evento,
      'TASK',
      NEW.id,
      v_vinc.solicitacao_id,
      NEW.id,
      jsonb_build_object(
        'task_id', NEW.id,
        'tarefa', NEW.tarefa,
        'papel_task', CASE WHEN v_vinc.task_principal_id = NEW.id THEN 'PRINCIPAL' ELSE 'APOIO' END,
        'data_inicio_anterior', OLD.data_inicio,
        'data_fim_anterior', OLD.data_fim,
        'data_inicio_nova', NEW.data_inicio,
        'data_fim_nova', NEW.data_fim,
        'status_anterior', OLD.status,
        'status_novo', NEW.status,
        'mudou_periodo', v_mudou_periodo,
        'mudou_recurso', v_mudou_recurso
      ),
      v_idem
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    IF v_vinc.solicitacao_id IS NOT NULL AND v_mudou_periodo THEN
      INSERT INTO public.tasks_apoios_historico (
        solicitacao_id, vinculo_id, task_relacionada_id, evento, justificativa, detalhes_json
      ) VALUES (
        v_vinc.solicitacao_id,
        v_vinc.vinculo_id,
        NEW.id,
        v_evento,
        'Alteração detectada automaticamente na atividade ' || COALESCE(NEW.tarefa, NEW.id::text),
        jsonb_build_object(
          'data_inicio_anterior', OLD.data_inicio,
          'data_fim_anterior', OLD.data_fim,
          'data_inicio_nova', NEW.data_inicio,
          'data_fim_nova', NEW.data_fim
        )
      );
    END IF;
  END LOOP;

  IF v_mudou_periodo OR (v_mudou_status AND UPPER(COALESCE(NEW.status, '')) IN ('CANC', 'CANCELADA')) THEN
    FOR v_sol IN
      SELECT s.id
      FROM public.tasks_apoios_solicitacoes s
      WHERE s.ativo = TRUE
        AND s.task_solicitante_id = NEW.id
        AND s.status NOT IN ('CANCELADA', 'RECUSADA')
        AND NOT EXISTS (
          SELECT 1 FROM public.tasks_apoios_vinculos v
          WHERE v.solicitacao_id = s.id AND v.ativo = TRUE
        )
    LOOP
      v_idem := 'TASK_SOL_UPD:' || NEW.id::text || ':' || v_evento || ':' || v_sol.id::text || ':' || v_tx_tag;
      INSERT INTO public.notificacoes_eventos_outbox (
        modulo, evento_tipo, entidade_tipo, entidade_id, solicitacao_id, task_id, payload_json, idempotency_key
      ) VALUES (
        'APOIOS_OPERACIONAIS',
        v_evento,
        'TASK',
        NEW.id,
        v_sol.id,
        NEW.id,
        jsonb_build_object(
          'task_id', NEW.id,
          'tarefa', NEW.tarefa,
          'papel_task', 'PRINCIPAL',
          'data_inicio_anterior', OLD.data_inicio,
          'data_fim_anterior', OLD.data_fim,
          'data_inicio_nova', NEW.data_inicio,
          'data_fim_nova', NEW.data_fim,
          'status_anterior', OLD.status,
          'status_novo', NEW.status
        ),
        v_idem
      ) ON CONFLICT (idempotency_key) DO NOTHING;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$function$;

-- 2. Monitoramento consolidado nas tabelas relacionais de períodos e recursos
--    (gantt_segments, executor_periods, frota_periods, tasks_executores,
--     tasks_frotas, tasks_equipes, tasks_locais).
--    Usa txid_current() por (task_id, tabela) para consolidar múltiplos inserts/deletes
--    de uma mesma operação em lote sem gerar spam intermediário.
CREATE OR REPLACE FUNCTION public.fn_monitorar_alteracao_relacional_apoio()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_task_id UUID;
  v_task_titulo TEXT;
  v_vinc RECORD;
  v_evento TEXT;
  v_idem TEXT;
BEGIN
  v_task_id := COALESCE(NEW.task_id, OLD.task_id);
  IF v_task_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.tasks_apoios_vinculos v
    WHERE v.ativo = TRUE AND (v.task_principal_id = v_task_id OR v.task_apoio_id = v_task_id)
  ) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT t.tarefa INTO v_task_titulo FROM public.tasks t WHERE t.id = v_task_id;
  v_evento := CASE
    WHEN TG_TABLE_NAME IN ('gantt_segments', 'executor_periods', 'frota_periods')
      THEN 'ATIVIDADE_REPROGRAMADA'
    ELSE 'RECURSO_ATIVIDADE_ALTERADO'
  END;

  FOR v_vinc IN
    SELECT DISTINCT v.solicitacao_id, v.id AS vinculo_id
    FROM public.tasks_apoios_vinculos v
    WHERE v.ativo = TRUE AND (v.task_principal_id = v_task_id OR v.task_apoio_id = v_task_id)
  LOOP
    -- Consolidação por transação (txid_current): evita flood em operações em lote
    v_idem := 'REL:' || TG_TABLE_NAME || ':' || v_task_id::text || ':' || COALESCE(v_vinc.solicitacao_id::text, v_vinc.vinculo_id::text) || ':' || txid_current()::text;
    INSERT INTO public.notificacoes_eventos_outbox (
      modulo, evento_tipo, entidade_tipo, entidade_id, solicitacao_id, task_id, payload_json, idempotency_key
    ) VALUES (
      'APOIOS_OPERACIONAIS',
      v_evento,
      'TASK',
      v_task_id,
      v_vinc.solicitacao_id,
      v_task_id,
      jsonb_build_object(
        'task_id', v_task_id,
        'tarefa', COALESCE(v_task_titulo, v_task_id::text),
        'origem_alteracao', TG_TABLE_NAME,
        'operacao', TG_OP
      ),
      v_idem
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END LOOP;

  RETURN COALESCE(NEW, OLD);
END;
$function$;

DROP TRIGGER IF EXISTS trg_apoios_mon_gantt_segments ON public.gantt_segments;
CREATE TRIGGER trg_apoios_mon_gantt_segments
  AFTER INSERT OR UPDATE OR DELETE ON public.gantt_segments
  FOR EACH ROW EXECUTE FUNCTION public.fn_monitorar_alteracao_relacional_apoio();

DROP TRIGGER IF EXISTS trg_apoios_mon_executor_periods ON public.executor_periods;
CREATE TRIGGER trg_apoios_mon_executor_periods
  AFTER INSERT OR UPDATE OR DELETE ON public.executor_periods
  FOR EACH ROW EXECUTE FUNCTION public.fn_monitorar_alteracao_relacional_apoio();

DROP TRIGGER IF EXISTS trg_apoios_mon_frota_periods ON public.frota_periods;
CREATE TRIGGER trg_apoios_mon_frota_periods
  AFTER INSERT OR UPDATE OR DELETE ON public.frota_periods
  FOR EACH ROW EXECUTE FUNCTION public.fn_monitorar_alteracao_relacional_apoio();

DROP TRIGGER IF EXISTS trg_apoios_mon_tasks_executores ON public.tasks_executores;
CREATE TRIGGER trg_apoios_mon_tasks_executores
  AFTER INSERT OR UPDATE OR DELETE ON public.tasks_executores
  FOR EACH ROW EXECUTE FUNCTION public.fn_monitorar_alteracao_relacional_apoio();

DROP TRIGGER IF EXISTS trg_apoios_mon_tasks_frotas ON public.tasks_frotas;
CREATE TRIGGER trg_apoios_mon_tasks_frotas
  AFTER INSERT OR UPDATE OR DELETE ON public.tasks_frotas
  FOR EACH ROW EXECUTE FUNCTION public.fn_monitorar_alteracao_relacional_apoio();

DROP TRIGGER IF EXISTS trg_apoios_mon_tasks_equipes ON public.tasks_equipes;
CREATE TRIGGER trg_apoios_mon_tasks_equipes
  AFTER INSERT OR UPDATE OR DELETE ON public.tasks_equipes
  FOR EACH ROW EXECUTE FUNCTION public.fn_monitorar_alteracao_relacional_apoio();

DROP TRIGGER IF EXISTS trg_apoios_mon_tasks_locais ON public.tasks_locais;
CREATE TRIGGER trg_apoios_mon_tasks_locais
  AFTER INSERT OR UPDATE OR DELETE ON public.tasks_locais
  FOR EACH ROW EXECUTE FUNCTION public.fn_monitorar_alteracao_relacional_apoio();

COMMIT;

