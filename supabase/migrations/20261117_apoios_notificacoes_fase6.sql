-- ============================================================================
-- TASKFLOW — FASE 6: NOTIFICAÇÕES INTERNAS, OUTBOX, PREFERÊNCIAS,
-- MONITORAMENTO CENTRALIZADO DE ATIVIDADES E COMUNICAÇÃO ENTRE UNIDADES
-- Ambiente: DEV ONLY
-- ============================================================================

BEGIN;

-- 1. Responsáveis designados por unidade (divisão/segmento) para Apoios
CREATE TABLE IF NOT EXISTS public.tasks_apoios_unidade_responsaveis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  regional_id UUID REFERENCES public.regionais(id) ON DELETE CASCADE,
  divisao_id UUID NOT NULL REFERENCES public.divisoes(id) ON DELETE CASCADE,
  segmento_id UUID REFERENCES public.segmentos(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  papel VARCHAR(30) NOT NULL DEFAULT 'RESPONSAVEL_APOIO'
    CHECK (papel IN ('RESPONSAVEL_APOIO', 'GESTOR', 'COORDENADOR')),
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_apoio_unidade_resp
  ON public.tasks_apoios_unidade_responsaveis(divisao_id, COALESCE(segmento_id, '00000000-0000-0000-0000-000000000000'::uuid), usuario_id);

-- 2. Infraestrutura genérica de Notificações Internas (reutilizável por outros módulos)
CREATE TABLE IF NOT EXISTS public.notificacoes_internas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  modulo VARCHAR(50) NOT NULL DEFAULT 'APOIOS_OPERACIONAIS',
  categoria VARCHAR(40) NOT NULL,
  evento_tipo VARCHAR(60) NOT NULL,
  severidade VARCHAR(20) NOT NULL DEFAULT 'INFO'
    CHECK (severidade IN ('INFO', 'ATENCAO', 'RISCO', 'CRITICO')),
  titulo TEXT NOT NULL,
  mensagem TEXT NOT NULL,
  entidade_tipo VARCHAR(50) NOT NULL,
  entidade_id UUID NOT NULL,
  task_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
  solicitacao_id UUID REFERENCES public.tasks_apoios_solicitacoes(id) ON DELETE SET NULL,
  unidade_origem_id UUID,
  unidade_origem_nome TEXT,
  unidade_destino_id UUID,
  unidade_destino_nome TEXT,
  ator_usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
  ator_nome TEXT,
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  idempotency_key VARCHAR(180) UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_internas_modulo_data
  ON public.notificacoes_internas(modulo, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_internas_solicitacao
  ON public.notificacoes_internas(solicitacao_id) WHERE solicitacao_id IS NOT NULL;

-- 3. Destinatários das notificações (controle individual de leitura e isolamento)
CREATE TABLE IF NOT EXISTS public.notificacoes_destinatarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notificacao_id UUID NOT NULL REFERENCES public.notificacoes_internas(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  lida BOOLEAN NOT NULL DEFAULT FALSE,
  lida_em TIMESTAMPTZ,
  arquivada BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_notif_destinatario UNIQUE (notificacao_id, usuario_id)
);

CREATE INDEX IF NOT EXISTS idx_notif_dest_usuario_lida
  ON public.notificacoes_destinatarios(usuario_id, lida, created_at DESC)
  WHERE arquivada = FALSE;

-- 4. Preferências de comunicação (individuais e por unidade organizacional)
CREATE TABLE IF NOT EXISTS public.notificacoes_preferencias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  escopo VARCHAR(20) NOT NULL CHECK (escopo IN ('USUARIO', 'UNIDADE')),
  usuario_id UUID REFERENCES public.usuarios(id) ON DELETE CASCADE,
  regional_id UUID REFERENCES public.regionais(id) ON DELETE CASCADE,
  divisao_id UUID REFERENCES public.divisoes(id) ON DELETE CASCADE,
  segmento_id UUID REFERENCES public.segmentos(id) ON DELETE CASCADE,
  modulo VARCHAR(50) NOT NULL DEFAULT 'APOIOS_OPERACIONAIS',
  receber_interna BOOLEAN NOT NULL DEFAULT TRUE,
  receber_telegram BOOLEAN NOT NULL DEFAULT TRUE,
  telegram_chat_id_destino TEXT,
  eventos_habilitados JSONB NOT NULL DEFAULT '["ALL"]'::jsonb,
  antecedencias_dias JSONB NOT NULL DEFAULT '[7, 3, 1, 0]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_notif_pref_usuario_modulo
  ON public.notificacoes_preferencias(usuario_id, modulo)
  WHERE escopo = 'USUARIO' AND usuario_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notif_pref_unidade_modulo
  ON public.notificacoes_preferencias(divisao_id, COALESCE(segmento_id, '00000000-0000-0000-0000-000000000000'::uuid), modulo)
  WHERE escopo = 'UNIDADE' AND divisao_id IS NOT NULL;

-- 5. Transactional Outbox para processamento confiável e idempotente de eventos
CREATE TABLE IF NOT EXISTS public.notificacoes_eventos_outbox (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  modulo VARCHAR(50) NOT NULL DEFAULT 'APOIOS_OPERACIONAIS',
  evento_tipo VARCHAR(60) NOT NULL,
  entidade_tipo VARCHAR(50) NOT NULL,
  entidade_id UUID NOT NULL,
  solicitacao_id UUID,
  task_id UUID,
  payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  idempotency_key VARCHAR(180) NOT NULL UNIQUE,
  status VARCHAR(25) NOT NULL DEFAULT 'PENDENTE'
    CHECK (status IN ('PENDENTE', 'PROCESSANDO', 'PROCESSADO', 'ERRO_TEMP', 'FALHA_PERMANENTE')),
  tentativas INTEGER NOT NULL DEFAULT 0,
  max_tentativas INTEGER NOT NULL DEFAULT 5,
  proximo_retry_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ultimo_erro TEXT,
  processado_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_outbox_pendentes
  ON public.notificacoes_eventos_outbox(status, proximo_retry_em)
  WHERE status IN ('PENDENTE', 'ERRO_TEMP');

-- 6. Auditoria de entregas por canal (INTERNO, TELEGRAM, CHAT)
CREATE TABLE IF NOT EXISTS public.notificacoes_entregas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outbox_id UUID REFERENCES public.notificacoes_eventos_outbox(id) ON DELETE SET NULL,
  notificacao_id UUID REFERENCES public.notificacoes_internas(id) ON DELETE SET NULL,
  canal VARCHAR(20) NOT NULL CHECK (canal IN ('INTERNO', 'TELEGRAM', 'CHAT')),
  destino_referencia TEXT,
  usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
  status VARCHAR(25) NOT NULL CHECK (status IN ('ENVIADO', 'FALHA_TEMP', 'FALHA_PERMANENTE', 'IGNORADO_PREF')),
  tentativas INTEGER NOT NULL DEFAULT 1,
  erro_mensagem TEXT,
  idempotency_key VARCHAR(200) UNIQUE,
  enviado_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_entregas_outbox
  ON public.notificacoes_entregas(outbox_id);

-- 7. Conversa operacional vinculada à solicitação de apoio (isolada às unidades participantes)
CREATE TABLE IF NOT EXISTS public.tasks_apoios_mensagens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitacao_id UUID NOT NULL REFERENCES public.tasks_apoios_solicitacoes(id) ON DELETE CASCADE,
  autor_usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  autor_nome TEXT NOT NULL,
  unidade_id UUID,
  mensagem TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apoios_mensagens_sol
  ON public.tasks_apoios_mensagens(solicitacao_id, created_at ASC);

-- 8. Monitoramento centralizado de alterações em public.tasks (sem bloquear salvamento)
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
  v_agora_bucket TEXT;
BEGIN
  -- Ignorar se não houver nenhuma relação com apoios
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
    v_agora_bucket := to_char(NOW() AT TIME ZONE 'UTC', 'YYYYMMDDHH24MISS');

    FOR v_vinc IN
      SELECT DISTINCT v.solicitacao_id, v.task_principal_id, v.task_apoio_id
      FROM public.tasks_apoios_vinculos v
      WHERE v.ativo = TRUE AND (v.task_principal_id = OLD.id OR v.task_apoio_id = OLD.id)
    LOOP
      v_idem := 'TASK_DEL:' || OLD.id::text || ':' || COALESCE(v_vinc.solicitacao_id::text, 'SEM_SOL') || ':' || v_agora_bucket;
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

  -- TG_OP = 'UPDATE': verificar apenas campos com impacto operacional relevante
  v_mudou_periodo := (NEW.data_inicio IS DISTINCT FROM OLD.data_inicio) OR (NEW.data_fim IS DISTINCT FROM OLD.data_fim);
  v_mudou_recurso := (NEW.frota IS DISTINCT FROM OLD.frota)
    OR (NEW.executor IS DISTINCT FROM OLD.executor)
    OR (NEW.equipe_id IS DISTINCT FROM OLD.equipe_id);
  v_mudou_status := (NEW.status IS DISTINCT FROM OLD.status);

  IF NOT (v_mudou_periodo OR v_mudou_recurso OR v_mudou_status) THEN
    RETURN NEW;
  END IF;

  -- Só prosseguir se houver vínculo ativo ou solicitação ativa ligada a esta task
  IF NOT EXISTS (
    SELECT 1 FROM public.tasks_apoios_vinculos v
    WHERE v.ativo = TRUE AND (v.task_principal_id = NEW.id OR v.task_apoio_id = NEW.id)
  ) AND NOT EXISTS (
    SELECT 1 FROM public.tasks_apoios_solicitacoes s
    WHERE s.ativo = TRUE AND s.task_solicitante_id = NEW.id AND s.status NOT IN ('CANCELADA', 'RECUSADA')
  ) THEN
    RETURN NEW;
  END IF;

  v_agora_bucket := to_char(NOW() AT TIME ZONE 'UTC', 'YYYYMMDDHH24MISS');

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

  -- Processar vínculos ativos afetados
  FOR v_vinc IN
    SELECT DISTINCT v.id AS vinculo_id, v.solicitacao_id, v.task_principal_id, v.task_apoio_id
    FROM public.tasks_apoios_vinculos v
    WHERE v.ativo = TRUE AND (v.task_principal_id = NEW.id OR v.task_apoio_id = NEW.id)
  LOOP
    v_idem := 'TASK_UPD:' || NEW.id::text || ':' || v_evento || ':' || COALESCE(v_vinc.solicitacao_id::text, v_vinc.vinculo_id::text) || ':' || v_agora_bucket;
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

  -- Processar solicitações ativas sem vínculo cujo solicitante foi reprogramado/cancelado
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
      v_idem := 'TASK_SOL_UPD:' || NEW.id::text || ':' || v_evento || ':' || v_sol.id::text || ':' || v_agora_bucket;
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

DROP TRIGGER IF EXISTS trg_monitorar_alteracao_task_apoio ON public.tasks;
CREATE TRIGGER trg_monitorar_alteracao_task_apoio
  AFTER UPDATE OR DELETE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_monitorar_alteracao_task_apoio();

-- 9. Segurança estrita (RLS + REVOKE para anon/authenticated; acesso exclusivo via service_role/gateway)
ALTER TABLE public.tasks_apoios_unidade_responsaveis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificacoes_internas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificacoes_destinatarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificacoes_preferencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificacoes_eventos_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificacoes_entregas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks_apoios_mensagens ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.tasks_apoios_unidade_responsaveis FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.notificacoes_internas FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.notificacoes_destinatarios FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.notificacoes_preferencias FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.notificacoes_eventos_outbox FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.notificacoes_entregas FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tasks_apoios_mensagens FROM PUBLIC, anon, authenticated;

GRANT ALL ON public.tasks_apoios_unidade_responsaveis TO service_role;
GRANT ALL ON public.notificacoes_internas TO service_role;
GRANT ALL ON public.notificacoes_destinatarios TO service_role;
GRANT ALL ON public.notificacoes_preferencias TO service_role;
GRANT ALL ON public.notificacoes_eventos_outbox TO service_role;
GRANT ALL ON public.notificacoes_entregas TO service_role;
GRANT ALL ON public.tasks_apoios_mensagens TO service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
