-- ==============================================================================
-- MIGRATION FASE 2: GESTÃO INTEGRADA DE APOIOS OPERACIONAIS E ATIVIDADES VINCULADAS
-- AMBIENTE ALVO: EXCLUSIVAMENTE DEV (NÃO APLICAR EM PRODUÇÃO SEM AUTORIZAÇÃO)
-- DATA: 2026-11-17
-- ==============================================================================
-- NOTA DE SEGURANÇA (AUDITORIA FASE 2):
-- O TaskFlow utiliza atualmente autenticação customizada via tabela public.usuarios
-- sem emissão de JWT do Supabase Auth (auth.uid() é NULL nas requisições anon).
-- Por determinação de segurança, NÃO são criadas políticas RLS permissivas USING (true)
-- nem RPCs públicas que confiem em p_usuario_id enviado pelo cliente.
-- Todas as tabelas operacionais, views e funções ficam protegidas por RLS (acesso
-- restrito a service_role/postgres) até a aprovação da estratégia de autenticação
-- verificável no backend.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 1. TABELA CONFIGURÁVEL DE TIPOS DE APOIO
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.tasks_apoios_tipos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo VARCHAR(40) NOT NULL UNIQUE,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT,
  icone VARCHAR(60),
  ordem INTEGER NOT NULL DEFAULT 0,
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.tasks_apoios_tipos (codigo, nome, descricao, icone, ordem, ativo)
VALUES
  ('FROTA_VEICULOS', 'Frota e veículos', 'Disponibilização de caminhões, Munck, caminhonetes e veículos operacionais', 'directions_car_outlined', 10, TRUE),
  ('MAQUINAS_EQUIPAMENTOS', 'Máquinas e equipamentos', 'Tratores, pranchas, geradores, guindastes e equipamentos pesados', 'precision_manufacturing_outlined', 20, TRUE),
  ('EQUIPE_APOIO', 'Equipe de apoio', 'Equipe operacional complementar para execução conjunta em campo', 'groups_outlined', 30, TRUE),
  ('APOIO_TECNICO', 'Apoio técnico especializado', 'Suporte técnico de engenharia, proteção, automação ou ensaios', 'engineering_outlined', 40, TRUE),
  ('OPERACAO_MANOBRAS', 'Operação e manobras', 'Realização de manobras, bloqueios, testes ou liberação operativa', 'electrical_services_outlined', 50, TRUE),
  ('TRANSPORTE', 'Transporte', 'Deslocamento de cargas, estruturas ou equipes entre localidades', 'local_shipping_outlined', 60, TRUE),
  ('LOGISTICA', 'Logística', 'Apoio logístico, hospedagem, acesso a faixas e suporte de campo', 'inventory_2_outlined', 70, TRUE),
  ('MATERIAIS', 'Materiais', 'Separação, fornecimento ou entrega de materiais e sobressalentes', 'category_outlined', 80, TRUE),
  ('INSPECOES', 'Inspeções', 'Inspeções prévias, termografias, comissionamento ou vistorias', 'fact_check_outlined', 90, TRUE),
  ('OUTROS', 'Outros', 'Outras demandas de apoio operacional entre unidades', 'handshake_outlined', 100, TRUE)
ON CONFLICT (codigo) DO UPDATE SET
  nome = EXCLUDED.nome,
  descricao = EXCLUDED.descricao,
  icone = EXCLUDED.icone,
  ordem = EXCLUDED.ordem;

CREATE INDEX IF NOT EXISTS idx_tasks_apoios_tipos_ativo_ordem
  ON public.tasks_apoios_tipos(ativo, ordem);

-- ==============================================================================
-- 2. TABELA DE SOLICITAÇÕES DE APOIO OPERACIONAL
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.tasks_apoios_solicitacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key VARCHAR(120),
  task_solicitante_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
  task_solicitante_titulo_snapshot TEXT NOT NULL,
  task_solicitante_ordem_snapshot VARCHAR(50),

  -- Unidade Solicitante
  regional_solicitante_id UUID NOT NULL REFERENCES public.regionais(id) ON DELETE RESTRICT,
  divisao_solicitante_id UUID NOT NULL REFERENCES public.divisoes(id) ON DELETE RESTRICT,
  segmento_solicitante_id UUID REFERENCES public.segmentos(id) ON DELETE RESTRICT,

  -- Unidade de Destino (segmento_destino_id pode ser NULL quando enviado para a Divisão)
  regional_destino_id UUID NOT NULL REFERENCES public.regionais(id) ON DELETE RESTRICT,
  divisao_destino_id UUID NOT NULL REFERENCES public.divisoes(id) ON DELETE RESTRICT,
  segmento_destino_id UUID REFERENCES public.segmentos(id) ON DELETE RESTRICT,

  -- Classificação
  tipo_apoio_id UUID NOT NULL REFERENCES public.tasks_apoios_tipos(id) ON DELETE RESTRICT,
  criticidade VARCHAR(20) NOT NULL DEFAULT 'ESSENCIAL'
    CHECK (criticidade IN ('ESSENCIAL', 'COMPLEMENTAR')),
  prioridade VARCHAR(10) NOT NULL DEFAULT 'MEDIA'
    CHECK (prioridade IN ('ALTA', 'MEDIA', 'BAIXA')),
  modalidade VARCHAR(30) NOT NULL DEFAULT 'SOLICITACAO'
    CHECK (modalidade IN ('SOLICITACAO', 'PROGRAMACAO_CONJUNTA')),

  -- Necessidade e Negociação (períodos preservados separadamente)
  descricao TEXT NOT NULL,
  locais_atendimento TEXT,
  data_inicio_solicitada TIMESTAMPTZ NOT NULL,
  data_fim_solicitada TIMESTAMPTZ NOT NULL,
  contraproposta_inicio TIMESTAMPTZ,
  contraproposta_fim TIMESTAMPTZ,
  contraproposta_justificativa TEXT,
  data_inicio_acordada TIMESTAMPTZ,
  data_fim_acordada TIMESTAMPTZ,
  prazo_resposta TIMESTAMPTZ,

  -- Máquina de Estados
  status VARCHAR(20) NOT NULL DEFAULT 'PENDENTE'
    CHECK (status IN ('PENDENTE', 'EM_ANALISE', 'CONTRAPROPOSTA', 'ACEITA', 'RECUSADA', 'CANCELADA')),
  justificativa_decisao TEXT,
  observacoes TEXT,

  -- Responsáveis, Versionamento Otimista e Cancelamento Lógico
  solicitante_usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  responsavel_atendimento_id UUID REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  versao INTEGER NOT NULL DEFAULT 1 CHECK (versao >= 1),
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  cancelado_em TIMESTAMPTZ,
  cancelado_por UUID REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  motivo_cancelamento TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_solicitacao_datas_solicitadas CHECK (data_fim_solicitada >= data_inicio_solicitada),
  CONSTRAINT chk_solicitacao_datas_contraproposta CHECK (
    contraproposta_inicio IS NULL OR contraproposta_fim IS NULL OR contraproposta_fim >= contraproposta_inicio
  ),
  CONSTRAINT chk_solicitacao_datas_acordadas CHECK (
    data_inicio_acordada IS NULL OR data_fim_acordada IS NULL OR data_fim_acordada >= data_inicio_acordada
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_tasks_apoios_solicitacoes_idempotency
  ON public.tasks_apoios_solicitacoes(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_apoios_sol_task_solicitante
  ON public.tasks_apoios_solicitacoes(task_solicitante_id)
  WHERE ativo = TRUE;

CREATE INDEX IF NOT EXISTS idx_apoios_sol_destino_status
  ON public.tasks_apoios_solicitacoes(regional_destino_id, divisao_destino_id, segmento_destino_id, status)
  WHERE ativo = TRUE;

CREATE INDEX IF NOT EXISTS idx_apoios_sol_solicitante_status
  ON public.tasks_apoios_solicitacoes(regional_solicitante_id, divisao_solicitante_id, status)
  WHERE ativo = TRUE;

CREATE INDEX IF NOT EXISTS idx_apoios_sol_datas
  ON public.tasks_apoios_solicitacoes(data_inicio_solicitada, data_fim_solicitada);

-- ==============================================================================
-- 3. TABELA NORMALIZADA DE PERÍODOS NECESSÁRIOS / NEGOCIADOS (SUPORTA DESCONTÍNUOS)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.tasks_apoios_solicitacoes_periodos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitacao_id UUID NOT NULL REFERENCES public.tasks_apoios_solicitacoes(id) ON DELETE CASCADE,
  origem_periodo VARCHAR(20) NOT NULL DEFAULT 'SOLICITADO'
    CHECK (origem_periodo IN ('SOLICITADO', 'CONTRAPROPOSTA', 'ACORDADO')),
  tipo_periodo VARCHAR(20) NOT NULL DEFAULT 'EXECUCAO'
    CHECK (tipo_periodo IN ('EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO')),
  data_inicio TIMESTAMPTZ NOT NULL,
  data_fim TIMESTAMPTZ NOT NULL,
  observacao TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_apoio_periodo_intervalo CHECK (data_fim >= data_inicio)
);

CREATE INDEX IF NOT EXISTS idx_apoios_sol_periodos_solicitacao
  ON public.tasks_apoios_solicitacoes_periodos(solicitacao_id, origem_periodo);

-- ==============================================================================
-- 4. TABELA DE VÍNCULOS LATERAIS ENTRE ATIVIDADES (N:N)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.tasks_apoios_vinculos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key VARCHAR(120),
  solicitacao_id UUID REFERENCES public.tasks_apoios_solicitacoes(id) ON DELETE RESTRICT,
  task_principal_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
  task_apoio_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
  task_principal_titulo_snapshot TEXT NOT NULL,
  task_apoio_titulo_snapshot TEXT NOT NULL,
  tipo_apoio_id UUID REFERENCES public.tasks_apoios_tipos(id) ON DELETE RESTRICT,
  finalidade VARCHAR(30) NOT NULL DEFAULT 'APOIO_OPERACIONAL'
    CHECK (finalidade IN ('APOIO_OPERACIONAL', 'VINCULO_DIRETO', 'PROGRAMACAO_CONJUNTA')),
  cobertura_inicio TIMESTAMPTZ,
  cobertura_fim TIMESTAMPTZ,
  observacao TEXT,
  autorizado_direto BOOLEAN NOT NULL DEFAULT FALSE,
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  versao INTEGER NOT NULL DEFAULT 1 CHECK (versao >= 1),
  desativado_em TIMESTAMPTZ,
  desativado_por UUID REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  motivo_desativacao TEXT,
  created_by UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_vinculo_sem_auto_referencia CHECK (
    task_principal_id IS NULL OR task_apoio_id IS NULL OR task_principal_id <> task_apoio_id
  ),
  CONSTRAINT chk_vinculo_cobertura_datas CHECK (
    cobertura_inicio IS NULL OR cobertura_fim IS NULL OR cobertura_fim >= cobertura_inicio
  ),
  CONSTRAINT chk_vinculo_tasks_presentes_quando_ativo CHECK (
    ativo = FALSE OR (task_principal_id IS NOT NULL AND task_apoio_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_tasks_apoios_vinculos_idempotency
  ON public.tasks_apoios_vinculos(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Permite que a mesma task_apoio_id atenda duas solicitações distintas da mesma task_principal_id
CREATE UNIQUE INDEX IF NOT EXISTS uq_vinculo_ativo_por_solicitacao
  ON public.tasks_apoios_vinculos(solicitacao_id, task_principal_id, task_apoio_id)
  WHERE ativo = TRUE AND solicitacao_id IS NOT NULL;

-- Impede vínculo direto duplicado para a mesma finalidade sem solicitação
CREATE UNIQUE INDEX IF NOT EXISTS uq_vinculo_direto_ativo
  ON public.tasks_apoios_vinculos(task_principal_id, task_apoio_id, finalidade)
  WHERE ativo = TRUE AND solicitacao_id IS NULL;

-- Previne duplicidade em sentidos opostos (A->B e B->A) na programação conjunta simétrica
CREATE UNIQUE INDEX IF NOT EXISTS uq_programacao_conjunta_simetrica
  ON public.tasks_apoios_vinculos(
    LEAST(task_principal_id, task_apoio_id),
    GREATEST(task_principal_id, task_apoio_id)
  )
  WHERE ativo = TRUE AND finalidade = 'PROGRAMACAO_CONJUNTA'
    AND task_principal_id IS NOT NULL AND task_apoio_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_apoios_vinculos_principal
  ON public.tasks_apoios_vinculos(task_principal_id)
  WHERE ativo = TRUE;

CREATE INDEX IF NOT EXISTS idx_apoios_vinculos_apoio
  ON public.tasks_apoios_vinculos(task_apoio_id)
  WHERE ativo = TRUE;

CREATE INDEX IF NOT EXISTS idx_apoios_vinculos_solicitacao
  ON public.tasks_apoios_vinculos(solicitacao_id)
  WHERE ativo = TRUE AND solicitacao_id IS NOT NULL;

-- ==============================================================================
-- 5. TABELA DE HISTÓRICO IMUTÁVEL DE APOIOS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.tasks_apoios_historico (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitacao_id UUID REFERENCES public.tasks_apoios_solicitacoes(id) ON DELETE SET NULL,
  vinculo_id UUID REFERENCES public.tasks_apoios_vinculos(id) ON DELETE SET NULL,
  task_relacionada_id UUID,
  evento VARCHAR(50) NOT NULL,
  status_anterior VARCHAR(20),
  status_novo VARCHAR(20),
  justificativa TEXT,
  detalhes_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  usuario_id UUID REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  usuario_nome TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apoios_hist_solicitacao
  ON public.tasks_apoios_historico(solicitacao_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_apoios_hist_vinculo
  ON public.tasks_apoios_historico(vinculo_id, created_at DESC);

-- ==============================================================================
-- 6. FUNÇÕES E TRIGGERS DE INTEGRIDADE, ESCOPO E MÁQUINA DE ESTADOS
-- ==============================================================================

-- 6.1. Imutabilidade do histórico
CREATE OR REPLACE FUNCTION public.fn_bloquear_mutacao_historico_apoio()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'O histórico de apoios operacionais é imutável e não pode ser alterado ou excluído.';
END;
$$;

DROP TRIGGER IF EXISTS trg_bloquear_mutacao_historico_apoio ON public.tasks_apoios_historico;
CREATE TRIGGER trg_bloquear_mutacao_historico_apoio
  BEFORE UPDATE OR DELETE ON public.tasks_apoios_historico
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_mutacao_historico_apoio();

-- 6.2. Validação rigorosa de combinação organizacional (Regional -> Divisão -> Segmento)
CREATE OR REPLACE FUNCTION public.fn_validar_escopo_organizacional_apoio(
  p_regional_id UUID,
  p_divisao_id UUID,
  p_segmento_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
BEGIN
  IF p_regional_id IS NULL OR p_divisao_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Validar vínculo Divisão <-> Regional
  IF NOT EXISTS (
    SELECT 1
    FROM public.divisoes_regionais dr
    WHERE dr.regional_id = p_regional_id
      AND dr.divisao_id = p_divisao_id
  ) THEN
    -- Fallback para coluna legada divisoes.regional_id caso exista
    IF NOT EXISTS (
      SELECT 1
      FROM public.divisoes d
      WHERE d.id = p_divisao_id
        AND d.regional_id = p_regional_id
    ) THEN
      RETURN FALSE;
    END IF;
  END IF;

  -- Validar vínculo Segmento <-> Divisão (quando segmento informado)
  IF p_segmento_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.divisoes_segmentos ds
      WHERE ds.divisao_id = p_divisao_id
        AND ds.segmento_id = p_segmento_id
    ) THEN
      RETURN FALSE;
    END IF;
  END IF;

  RETURN TRUE;
END;
$$;

-- 6.3. Trigger de validação e máquina de estados em tasks_apoios_solicitacoes
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

  -- UPDATE: validar controle de versão otimista (permite passagem interna se versao = OLD.versao + 1 ou se igual com incremento)
  IF NEW.versao <> OLD.versao AND NEW.versao <> OLD.versao + 1 THEN
    RAISE EXCEPTION 'Conflito de versão na solicitação % (esperada: %, informada: %).', OLD.id, OLD.versao, NEW.versao;
  END IF;

  -- Validar máquina de estados
  IF NEW.status <> OLD.status THEN
    v_transicao_valida := CASE OLD.status
      WHEN 'PENDENTE' THEN NEW.status IN ('EM_ANALISE', 'CONTRAPROPOSTA', 'ACEITA', 'RECUSADA', 'CANCELADA')
      WHEN 'EM_ANALISE' THEN NEW.status IN ('CONTRAPROPOSTA', 'ACEITA', 'RECUSADA', 'CANCELADA')
      WHEN 'CONTRAPROPOSTA' THEN NEW.status IN ('ACEITA', 'RECUSADA', 'CANCELADA', 'CONTRAPROPOSTA')
      WHEN 'ACEITA' THEN NEW.status IN ('CANCELADA', 'CONTRAPROPOSTA')
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
      -- Preservar períodos solicitados/propostos e registrar período acordado
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

DROP TRIGGER IF EXISTS trg_before_solicitacao_apoio ON public.tasks_apoios_solicitacoes;
CREATE TRIGGER trg_before_solicitacao_apoio
  BEFORE INSERT OR UPDATE ON public.tasks_apoios_solicitacoes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_before_solicitacao_apoio();

-- 6.4. Registro automático e transacional no histórico após INSERT/UPDATE em solicitações
CREATE OR REPLACE FUNCTION public.fn_after_solicitacao_apoio_hist()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_evento VARCHAR(50);
  v_uid UUID;
  v_unome TEXT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_evento := 'SOLICITACAO_CRIADA';
    v_uid := NEW.solicitante_usuario_id;
  ELSIF NEW.status <> OLD.status THEN
    v_evento := 'STATUS_' || NEW.status;
    v_uid := COALESCE(NEW.cancelado_por, NEW.responsavel_atendimento_id, NEW.solicitante_usuario_id);
  ELSIF NEW.segmento_destino_id IS DISTINCT FROM OLD.segmento_destino_id THEN
    v_evento := 'ENCAMINHADA_SEGMENTO';
    v_uid := COALESCE(NEW.responsavel_atendimento_id, NEW.solicitante_usuario_id);
  ELSE
    v_evento := 'SOLICITACAO_ATUALIZADA';
    v_uid := COALESCE(NEW.responsavel_atendimento_id, NEW.solicitante_usuario_id);
  END IF;

  SELECT u.nome INTO v_unome FROM public.usuarios u WHERE u.id = v_uid;

  INSERT INTO public.tasks_apoios_historico (
    solicitacao_id,
    task_relacionada_id,
    evento,
    status_anterior,
    status_novo,
    justificativa,
    detalhes_json,
    usuario_id,
    usuario_nome
  ) VALUES (
    NEW.id,
    NEW.task_solicitante_id,
    v_evento,
    CASE WHEN TG_OP = 'UPDATE' THEN OLD.status ELSE NULL END,
    NEW.status,
    COALESCE(NEW.motivo_cancelamento, NEW.justificativa_decisao, NEW.contraproposta_justificativa),
    jsonb_build_object(
      'versao', NEW.versao,
      'criticidade', NEW.criticidade,
      'divisao_destino_id', NEW.divisao_destino_id,
      'segmento_destino_id', NEW.segmento_destino_id,
      'data_inicio_solicitada', NEW.data_inicio_solicitada,
      'data_fim_solicitada', NEW.data_fim_solicitada,
      'data_inicio_acordada', NEW.data_inicio_acordada,
      'data_fim_acordada', NEW.data_fim_acordada
    ),
    v_uid,
    v_unome
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_after_solicitacao_apoio_hist ON public.tasks_apoios_solicitacoes;
CREATE TRIGGER trg_after_solicitacao_apoio_hist
  AFTER INSERT OR UPDATE ON public.tasks_apoios_solicitacoes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_after_solicitacao_apoio_hist();

-- 6.5. Validação e histórico em tasks_apoios_vinculos
CREATE OR REPLACE FUNCTION public.fn_before_vinculo_apoio()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
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

  -- UPDATE
  IF NEW.ativo = FALSE AND OLD.ativo = TRUE THEN
    NEW.desativado_em := COALESCE(NEW.desativado_em, NOW());
  END IF;

  NEW.versao := OLD.versao + 1;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_before_vinculo_apoio ON public.tasks_apoios_vinculos;
CREATE TRIGGER trg_before_vinculo_apoio
  BEFORE INSERT OR UPDATE ON public.tasks_apoios_vinculos
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_before_vinculo_apoio();

CREATE OR REPLACE FUNCTION public.fn_after_vinculo_apoio_hist()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_evento VARCHAR(50);
  v_uid UUID;
  v_unome TEXT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_evento := 'VINCULO_CRIADO';
    v_uid := NEW.created_by;
  ELSIF NEW.ativo = FALSE AND OLD.ativo = TRUE THEN
    v_evento := 'VINCULO_DESATIVADO';
    v_uid := COALESCE(NEW.desativado_por, NEW.created_by);
  ELSE
    v_evento := 'VINCULO_ATUALIZADO';
    v_uid := NEW.created_by;
  END IF;

  SELECT u.nome INTO v_unome FROM public.usuarios u WHERE u.id = v_uid;

  INSERT INTO public.tasks_apoios_historico (
    solicitacao_id,
    vinculo_id,
    task_relacionada_id,
    evento,
    justificativa,
    detalhes_json,
    usuario_id,
    usuario_nome
  ) VALUES (
    NEW.solicitacao_id,
    NEW.id,
    COALESCE(NEW.task_apoio_id, NEW.task_principal_id),
    v_evento,
    NEW.motivo_desativacao,
    jsonb_build_object(
      'task_principal_id', NEW.task_principal_id,
      'task_apoio_id', NEW.task_apoio_id,
      'finalidade', NEW.finalidade,
      'autorizado_direto', NEW.autorizado_direto
    ),
    v_uid,
    v_unome
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_after_vinculo_apoio_hist ON public.tasks_apoios_vinculos;
CREATE TRIGGER trg_after_vinculo_apoio_hist
  AFTER INSERT OR UPDATE ON public.tasks_apoios_vinculos
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_after_vinculo_apoio_hist();

-- 6.6. Preservação de histórico quando uma tarefa é excluída de public.tasks
CREATE OR REPLACE FUNCTION public.fn_preservar_apoios_antes_delete_task()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- 1. Desativar vínculos antes que a FK ON DELETE SET NULL anule a referência
  UPDATE public.tasks_apoios_vinculos
  SET
    ativo = FALSE,
    desativado_em = NOW(),
    motivo_desativacao = COALESCE(motivo_desativacao, 'Atividade vinculada excluída do sistema')
  WHERE ativo = TRUE
    AND (task_principal_id = OLD.id OR task_apoio_id = OLD.id);

  -- 2. Cancelar solicitações ainda abertas desta tarefa preservando o snapshot
  UPDATE public.tasks_apoios_solicitacoes
  SET
    status = 'CANCELADA',
    ativo = FALSE,
    cancelado_em = NOW(),
    motivo_cancelamento = COALESCE(motivo_cancelamento, 'Atividade solicitante excluída do sistema')
  WHERE task_solicitante_id = OLD.id
    AND status IN ('PENDENTE', 'EM_ANALISE', 'CONTRAPROPOSTA', 'ACEITA');

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_preservar_apoios_antes_delete_task ON public.tasks;
CREATE TRIGGER trg_preservar_apoios_antes_delete_task
  BEFORE DELETE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_preservar_apoios_antes_delete_task();

-- ==============================================================================
-- 7. VIEWS CONSOLIDADAS DE CONSULTA E SITUAÇÃO OPERACIONAL (SEM N+1)
-- ==============================================================================
DROP VIEW IF EXISTS public.v_tasks_apoios_resumo_task CASCADE;
DROP VIEW IF EXISTS public.v_tasks_apoios_situacao CASCADE;

CREATE VIEW public.v_tasks_apoios_situacao AS
WITH vinculos_ativos AS (
  SELECT
    v.id AS vinculo_id,
    v.solicitacao_id,
    v.task_principal_id,
    v.task_apoio_id,
    t_apoio.tarefa AS task_apoio_titulo,
    t_apoio.status AS task_apoio_status,
    t_apoio.data_inicio AS task_apoio_inicio,
    t_apoio.data_fim AS task_apoio_fim,
    t_apoio.regional_id AS task_apoio_regional_id,
    t_apoio.divisao_id AS task_apoio_divisao_id,
    t_apoio.segmento_id AS task_apoio_segmento_id,
    v.cobertura_inicio,
    v.cobertura_fim
  FROM public.tasks_apoios_vinculos v
  LEFT JOIN public.tasks t_apoio ON t_apoio.id = v.task_apoio_id
  WHERE v.ativo = TRUE AND v.solicitacao_id IS NOT NULL
),
agregado_por_solicitacao AS (
  SELECT
    s.id AS solicitacao_id,
    COUNT(va.vinculo_id)::INTEGER AS qtd_vinculos_ativos,
    COUNT(va.vinculo_id) FILTER (WHERE UPPER(TRIM(COALESCE(va.task_apoio_status, ''))) = 'CONC')::INTEGER AS qtd_concluidos,
    COUNT(va.vinculo_id) FILTER (WHERE UPPER(TRIM(COALESCE(va.task_apoio_status, ''))) = 'ANDA')::INTEGER AS qtd_andamento,
    COUNT(va.vinculo_id) FILTER (WHERE UPPER(TRIM(COALESCE(va.task_apoio_status, ''))) = 'CANC')::INTEGER AS qtd_cancelados,
    COUNT(va.vinculo_id) FILTER (
      WHERE UPPER(TRIM(COALESCE(va.task_apoio_status, ''))) NOT IN ('CANC', '')
        AND (
          va.task_apoio_inicio > COALESCE(s.data_inicio_acordada, s.data_inicio_solicitada)
          OR va.task_apoio_fim < COALESCE(s.data_fim_acordada, s.data_fim_solicitada)
        )
    )::INTEGER AS qtd_incompativeis,
    MIN(va.task_apoio_inicio) AS menor_inicio_programado,
    MAX(va.task_apoio_fim) AS maior_fim_programado
  FROM public.tasks_apoios_solicitacoes s
  LEFT JOIN vinculos_ativos va ON va.solicitacao_id = s.id
  GROUP BY s.id
)
SELECT
  s.id AS solicitacao_id,
  s.task_solicitante_id,
  s.task_solicitante_titulo_snapshot,
  s.regional_solicitante_id,
  s.divisao_solicitante_id,
  s.segmento_solicitante_id,
  s.regional_destino_id,
  s.divisao_destino_id,
  s.segmento_destino_id,
  s.tipo_apoio_id,
  tp.codigo AS tipo_apoio_codigo,
  tp.nome AS tipo_apoio_nome,
  s.criticidade,
  s.prioridade,
  s.modalidade,
  s.status AS status_negociacao,
  s.data_inicio_solicitada,
  s.data_fim_solicitada,
  s.data_inicio_acordada,
  s.data_fim_acordada,
  s.prazo_resposta,
  s.versao,
  ag.qtd_vinculos_ativos,
  ag.menor_inicio_programado,
  ag.maior_fim_programado,
  CASE
    WHEN s.status = 'CANCELADA' THEN 'CANCELADO'
    WHEN s.status = 'RECUSADA' THEN 'RECUSADO'
    WHEN s.status = 'PENDENTE' THEN 'SOLICITADO'
    WHEN s.status IN ('EM_ANALISE', 'CONTRAPROPOSTA') THEN 'EM_NEGOCIACAO'
    WHEN s.status = 'ACEITA' AND ag.qtd_vinculos_ativos = 0 THEN 'ACEITO_NAO_PROGRAMADO'
    WHEN ag.qtd_vinculos_ativos > 0 AND ag.qtd_concluidos = ag.qtd_vinculos_ativos THEN 'CONCLUIDO'
    WHEN ag.qtd_vinculos_ativos > 0 AND ag.qtd_andamento > 0 THEN 'EM_ANDAMENTO'
    WHEN ag.qtd_vinculos_ativos > 0 AND ag.qtd_incompativeis > 0 THEN 'PROGRAMADO_INCOMPATIVEL'
    WHEN ag.qtd_vinculos_ativos > 0 AND (
      ag.menor_inicio_programado > COALESCE(s.data_inicio_acordada, s.data_inicio_solicitada)
      OR ag.maior_fim_programado < COALESCE(s.data_fim_acordada, s.data_fim_solicitada)
    ) THEN 'PROGRAMADO_PARCIAL'
    WHEN ag.qtd_vinculos_ativos > 0 THEN 'PROGRAMADO_COMPATIVEL'
    ELSE 'SOLICITADO'
  END AS situacao_operacional
FROM public.tasks_apoios_solicitacoes s
INNER JOIN public.tasks_apoios_tipos tp ON tp.id = s.tipo_apoio_id
INNER JOIN agregado_por_solicitacao ag ON ag.solicitacao_id = s.id;

CREATE VIEW public.v_tasks_apoios_resumo_task AS
WITH resumo_sol AS (
  SELECT
    task_solicitante_id AS task_id,
    COUNT(*)::INTEGER AS total_solicitacoes,
    COUNT(*) FILTER (WHERE situacao_operacional IN ('SOLICITADO', 'EM_NEGOCIACAO'))::INTEGER AS qtd_aguardando_resposta,
    COUNT(*) FILTER (WHERE situacao_operacional = 'ACEITO_NAO_PROGRAMADO')::INTEGER AS qtd_aceitos_sem_programacao,
    COUNT(*) FILTER (WHERE situacao_operacional IN ('PROGRAMADO_INCOMPATIVEL', 'PROGRAMADO_PARCIAL'))::INTEGER AS qtd_incompativeis,
    COUNT(*) FILTER (WHERE criticidade = 'ESSENCIAL' AND situacao_operacional IN ('SOLICITADO', 'EM_NEGOCIACAO', 'ACEITO_NAO_PROGRAMADO', 'RECUSADO'))::INTEGER AS qtd_essenciais_pendentes,
    COUNT(*) FILTER (WHERE criticidade = 'ESSENCIAL' AND situacao_operacional IN ('PROGRAMADO_COMPATIVEL', 'EM_ANDAMENTO', 'CONCLUIDO'))::INTEGER AS qtd_essenciais_atendidos,
    COUNT(*) FILTER (WHERE criticidade = 'ESSENCIAL')::INTEGER AS total_essenciais
  FROM public.v_tasks_apoios_situacao
  WHERE task_solicitante_id IS NOT NULL
    AND status_negociacao <> 'CANCELADA'
  GROUP BY task_solicitante_id
),
resumo_prestados AS (
  SELECT
    v.task_apoio_id AS task_id,
    COUNT(DISTINCT v.id)::INTEGER AS qtd_atividades_apoiadas
  FROM public.tasks_apoios_vinculos v
  WHERE v.ativo = TRUE AND v.task_apoio_id IS NOT NULL
  GROUP BY v.task_apoio_id
)
SELECT
  t.id AS task_id,
  COALESCE(rs.total_solicitacoes, 0) AS total_solicitacoes,
  COALESCE(rs.qtd_aguardando_resposta, 0) AS qtd_aguardando_resposta,
  COALESCE(rs.qtd_aceitos_sem_programacao, 0) AS qtd_aceitos_sem_programacao,
  COALESCE(rs.qtd_incompativeis, 0) AS qtd_incompativeis,
  COALESCE(rs.qtd_essenciais_pendentes, 0) AS qtd_essenciais_pendentes,
  COALESCE(rp.qtd_atividades_apoiadas, 0) AS qtd_atividades_apoiadas,
  CASE
    WHEN COALESCE(rs.total_solicitacoes, 0) = 0 THEN 'SEM_DEPENDENCIAS'
    WHEN COALESCE(rs.total_essenciais, 0) = 0 THEN 'APENAS_COMPLEMENTARES'
    WHEN COALESCE(rs.qtd_incompativeis, 0) > 0 THEN 'PROGRAMACAO_EM_RISCO'
    WHEN COALESCE(rs.qtd_essenciais_pendentes, 0) > 0 AND COALESCE(rs.qtd_aceitos_sem_programacao, 0) > 0 THEN 'ACEITO_NAO_PROGRAMADO'
    WHEN COALESCE(rs.qtd_essenciais_pendentes, 0) > 0 THEN 'AGUARDANDO_CONFIRMACAO_ESSENCIAL'
    WHEN COALESCE(rs.qtd_essenciais_atendidos, 0) = COALESCE(rs.total_essenciais, 0) THEN 'ESSENCIAIS_PROGRAMADOS_COMPATIVEIS'
    ELSE 'AGUARDANDO_CONFIRMACAO_ESSENCIAL'
  END AS situacao_integrada
FROM public.tasks t
LEFT JOIN resumo_sol rs ON rs.task_id = t.id
LEFT JOIN resumo_prestados rp ON rp.task_id = t.id
WHERE COALESCE(rs.total_solicitacoes, 0) > 0 OR COALESCE(rp.qtd_atividades_apoiadas, 0) > 0;

-- ==============================================================================
-- 8. ROW LEVEL SECURITY (RLS) E PERMISSÕES RESTRITAS (ZERO USING (true))
-- ==============================================================================
ALTER TABLE public.tasks_apoios_tipos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks_apoios_solicitacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks_apoios_solicitacoes_periodos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks_apoios_vinculos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks_apoios_historico ENABLE ROW LEVEL SECURITY;

-- Catálogo de tipos: leitura somente de ativos; escrita restrita a service_role
DROP POLICY IF EXISTS "Leitura de tipos de apoio ativos" ON public.tasks_apoios_tipos;
CREATE POLICY "Leitura de tipos de apoio ativos"
  ON public.tasks_apoios_tipos
  FOR SELECT
  USING (ativo = TRUE);

-- Tabelas operacionais e histórico: SEM políticas abertas para anon/authenticated
-- até aprovação da camada de autenticação verificável por token/JWT.
REVOKE ALL ON public.tasks_apoios_solicitacoes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tasks_apoios_solicitacoes_periodos FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tasks_apoios_vinculos FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tasks_apoios_historico FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.v_tasks_apoios_situacao FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.v_tasks_apoios_resumo_task FROM PUBLIC, anon, authenticated;

-- Garantir privilégios exclusivos ao service_role / postgres
GRANT ALL ON public.tasks_apoios_tipos TO service_role;
GRANT ALL ON public.tasks_apoios_solicitacoes TO service_role;
GRANT ALL ON public.tasks_apoios_solicitacoes_periodos TO service_role;
GRANT ALL ON public.tasks_apoios_vinculos TO service_role;
GRANT ALL ON public.tasks_apoios_historico TO service_role;
GRANT SELECT ON public.v_tasks_apoios_situacao TO service_role;
GRANT SELECT ON public.v_tasks_apoios_resumo_task TO service_role;

-- Recarregar cache do PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;

