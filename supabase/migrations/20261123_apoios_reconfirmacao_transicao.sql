-- Alinha a máquina de estados do PostgreSQL (fn_before_solicitacao_apoio)
-- com a TaskApoioStateMachine do frontend, permitindo solicitar reconfirmação
-- (ACEITA -> EM_ANALISE) e encaminhar contraproposta para análise (CONTRAPROPOSTA -> EM_ANALISE).

CREATE OR REPLACE FUNCTION public.fn_before_solicitacao_apoio()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_task_reg UUID;
  v_task_div UUID;
  v_transicao_valida BOOLEAN := FALSE;
BEGIN
  -- Validar combinações organizacionais reais
  IF NOT public.fn_validar_escopo_organizacional_apoio(
    NEW.regional_solicitante_id,
    NEW.divisao_solicitante_id,
    NEW.segmento_solicitante_id
  ) THEN
    RAISE EXCEPTION 'Unidade solicitante inválida: divisão não pertence à regional ou segmento não pertence à divisão.';
  END IF;

  IF NOT public.fn_validar_escopo_organizacional_apoio(
    NEW.regional_destino_id,
    NEW.divisao_destino_id,
    NEW.segmento_destino_id
  ) THEN
    RAISE EXCEPTION 'Unidade de destino inválida: divisão não pertence à regional ou segmento não pertence à divisão.';
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Validar compatibilidade com a tarefa solicitante quando informada
    IF NEW.task_solicitante_id IS NOT NULL THEN
      SELECT t.regional_id, t.divisao_id
      INTO v_task_reg, v_task_div
      FROM public.tasks t
      WHERE t.id = NEW.task_solicitante_id;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Atividade solicitante (%) não encontrada.', NEW.task_solicitante_id;
      END IF;

      IF v_task_reg IS NOT NULL AND v_task_reg <> NEW.regional_solicitante_id THEN
        RAISE EXCEPTION 'Regional solicitante (%) incompatível com a regional da atividade (%).', NEW.regional_solicitante_id, v_task_reg;
      END IF;

      IF v_task_div IS NOT NULL AND v_task_div <> NEW.divisao_solicitante_id THEN
        RAISE EXCEPTION 'Divisão solicitante (%) incompatível com a divisão da atividade (%).', NEW.divisao_solicitante_id, v_task_div;
      END IF;
    END IF;

    IF NEW.status <> 'PENDENTE' THEN
      RAISE EXCEPTION 'Nova solicitação deve iniciar com status PENDENTE (recebido: %).', NEW.status;
    END IF;

    NEW.versao := COALESCE(NEW.versao, 1);
    NEW.created_at := COALESCE(NEW.created_at, NOW());
    NEW.updated_at := NOW();
    RETURN NEW;
  END IF;

  -- UPDATE: validar controle de versão otimista
  IF NEW.versao <> OLD.versao AND NEW.versao <> OLD.versao + 1 THEN
    RAISE EXCEPTION 'Conflito de versão na solicitação % (esperada: %, informada: %).', OLD.id, OLD.versao, NEW.versao;
  END IF;

  -- Validar máquina de estados
  IF NEW.status <> OLD.status THEN
    v_transicao_valida := CASE OLD.status
      WHEN 'PENDENTE' THEN NEW.status IN ('EM_ANALISE', 'CONTRAPROPOSTA', 'ACEITA', 'RECUSADA', 'CANCELADA')
      WHEN 'EM_ANALISE' THEN NEW.status IN ('CONTRAPROPOSTA', 'ACEITA', 'RECUSADA', 'CANCELADA')
      WHEN 'CONTRAPROPOSTA' THEN NEW.status IN ('ACEITA', 'RECUSADA', 'CANCELADA', 'CONTRAPROPOSTA', 'EM_ANALISE')
      WHEN 'ACEITA' THEN NEW.status IN ('CANCELADA', 'CONTRAPROPOSTA', 'EM_ANALISE')
      WHEN 'RECUSADA' THEN FALSE
      WHEN 'CANCELADA' THEN FALSE
      ELSE FALSE
    END;

    IF NOT v_transicao_valida THEN
      RAISE EXCEPTION 'Transição de status inválida: % -> %.', OLD.status, NEW.status;
    END IF;

    -- Exigir justificativa nos estados que demandam motivação
    IF NEW.status = 'RECUSADA' AND COALESCE(TRIM(NEW.justificativa_decisao), '') = '' THEN
      RAISE EXCEPTION 'Justificativa é obrigatória ao recusar uma solicitação.';
    END IF;

    IF NEW.status = 'CONTRAPROPOSTA' AND (
      NEW.contraproposta_inicio IS NULL OR NEW.contraproposta_fim IS NULL OR
      COALESCE(TRIM(NEW.contraproposta_justificativa), '') = ''
    ) THEN
      RAISE EXCEPTION 'Contraproposta exige período proposto e justificativa.';
    END IF;

    IF NEW.status = 'CANCELADA' THEN
      NEW.ativo := FALSE;
      NEW.cancelado_em := COALESCE(NEW.cancelado_em, NOW());
      IF COALESCE(TRIM(NEW.motivo_cancelamento), '') = '' AND COALESCE(TRIM(NEW.justificativa_decisao), '') = '' THEN
        RAISE EXCEPTION 'Motivo do cancelamento é obrigatório.';
      END IF;
    END IF;

    IF NEW.status = 'ACEITA' THEN
      IF OLD.status = 'CONTRAPROPOSTA' AND NEW.data_inicio_acordada IS NULL THEN
        NEW.data_inicio_acordada := NEW.contraproposta_inicio;
        NEW.data_fim_acordada := NEW.contraproposta_fim;
      ELSIF NEW.data_inicio_acordada IS NULL THEN
        NEW.data_inicio_acordada := NEW.data_inicio_solicitada;
        NEW.data_fim_acordada := NEW.data_fim_solicitada;
      END IF;
    END IF;
  END IF;

  NEW.versao := OLD.versao + 1;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

