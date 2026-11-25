-- ============================================================================
-- TASKFLOW — GESTÃO INTEGRADA DE APOIOS OPERACIONAIS (FASE 3 - AJUSTES PONTUAIS)
-- Ambiente: DEV ONLY
-- Finalidade:
--   1. Incluir prioridade 'URGENTE' na constraint de tasks_apoios_solicitacoes
--   2. Adicionar coluna opcional requisitos_recursos_json (JSONB) para
--      representação estruturada não-obrigatória de requisitos de recursos
--   3. Validar conflito de concorrência otimista (versao) em UPDATE de vínculos
-- ============================================================================

BEGIN;

-- 1. Prioridades disponíveis incluindo 'URGENTE'
ALTER TABLE public.tasks_apoios_solicitacoes
  DROP CONSTRAINT IF EXISTS tasks_apoios_solicitacoes_prioridade_check;

ALTER TABLE public.tasks_apoios_solicitacoes
  ADD CONSTRAINT tasks_apoios_solicitacoes_prioridade_check
  CHECK (prioridade IN ('URGENTE', 'ALTA', 'MEDIA', 'BAIXA'));

-- 2. Requisitos estruturados opcionais de recursos
ALTER TABLE public.tasks_apoios_solicitacoes
  ADD COLUMN IF NOT EXISTS requisitos_recursos_json JSONB;

-- 3. Concorrência otimista no UPDATE de tasks_apoios_vinculos
CREATE OR REPLACE FUNCTION public.fn_before_vinculo_apoio()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_sol public.tasks_apoios_solicitacoes%ROWTYPE;
  v_apoio_reg UUID;
  v_apoio_div UUID;
  v_apoio_seg UUID;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.solicitacao_id IS NOT NULL THEN
      SELECT * INTO v_sol
      FROM public.tasks_apoios_solicitacoes s
      WHERE s.id = NEW.solicitacao_id;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Solicitação (%) não encontrada.', NEW.solicitacao_id;
      END IF;

      IF v_sol.status IN ('RECUSADA', 'CANCELADA') THEN
        RAISE EXCEPTION 'Não é possível vincular atividade a uma solicitação com status %.', v_sol.status;
      END IF;

      IF v_sol.task_solicitante_id IS NOT NULL AND NEW.task_principal_id <> v_sol.task_solicitante_id THEN
        RAISE EXCEPTION 'A tarefa principal do vínculo difere da tarefa da solicitação.';
      END IF;

      -- Validar compatibilidade da atividade de apoio com a unidade de destino da solicitação
      IF NEW.task_apoio_id IS NOT NULL THEN
        SELECT t.regional_id, t.divisao_id, t.segmento_id
        INTO v_apoio_reg, v_apoio_div, v_apoio_seg
        FROM public.tasks t
        WHERE t.id = NEW.task_apoio_id;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'Atividade de apoio (%) não encontrada.', NEW.task_apoio_id;
        END IF;

        IF v_apoio_reg IS NOT NULL AND v_apoio_reg <> v_sol.regional_destino_id THEN
          RAISE EXCEPTION 'Atividade de apoio pertence a regional diferente do destino da solicitação.';
        END IF;

        IF v_apoio_div IS NOT NULL AND v_apoio_div <> v_sol.divisao_destino_id THEN
          RAISE EXCEPTION 'Atividade de apoio pertence a divisão diferente do destino da solicitação.';
        END IF;

        IF v_sol.segmento_destino_id IS NOT NULL AND v_apoio_seg IS NOT NULL AND v_apoio_seg <> v_sol.segmento_destino_id THEN
          RAISE EXCEPTION 'Atividade de apoio pertence a segmento diferente do destino da solicitação.';
        END IF;
      END IF;
    END IF;

    NEW.versao := COALESCE(NEW.versao, 1);
    NEW.created_at := COALESCE(NEW.created_at, NOW());
    NEW.updated_at := NOW();
    RETURN NEW;
  END IF;

  -- UPDATE: validar concorrência otimista
  IF NEW.versao IS DISTINCT FROM OLD.versao THEN
    RAISE EXCEPTION 'Conflito de versão no vínculo % (esperada: %, informada: %).',
      OLD.id, OLD.versao, NEW.versao;
  END IF;

  IF NEW.ativo = FALSE AND OLD.ativo = TRUE THEN
    NEW.desativado_em := COALESCE(NEW.desativado_em, NOW());
  END IF;

  NEW.versao := OLD.versao + 1;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$function$;

NOTIFY pgrst, 'reload schema';

COMMIT;

