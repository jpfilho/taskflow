-- ============================================================================
-- TaskFlow — Apoios Operacionais — Fase 8 (Hardening, Revogação e Confirmação)
-- ============================================================================

BEGIN;

-- 1. Tabela de revogação persistente de tokens do gateway de Apoios
CREATE TABLE IF NOT EXISTS public.tasks_apoios_tokens_revogados (
  jti TEXT PRIMARY KEY,
  usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  motivo VARCHAR(80) DEFAULT 'LOGOUT'
);

CREATE INDEX IF NOT EXISTS idx_apoios_tokens_revogados_exp
  ON public.tasks_apoios_tokens_revogados (expires_at);

-- 2. Confirmação persistente em tasks_apoios_vinculos
ALTER TABLE public.tasks_apoios_vinculos
  ADD COLUMN IF NOT EXISTS status_confirmacao VARCHAR(30) NOT NULL DEFAULT 'CONFIRMADO',
  ADD COLUMN IF NOT EXISTS confirmado_por UUID REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS confirmado_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS justificativa_confirmacao TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_vinculos_status_confirmacao'
      AND conrelid = 'public.tasks_apoios_vinculos'::regclass
  ) THEN
    ALTER TABLE public.tasks_apoios_vinculos
      ADD CONSTRAINT chk_vinculos_status_confirmacao
      CHECK (status_confirmacao IN ('AGUARDANDO_CONFIRMACAO', 'CONFIRMADO', 'RECUSADO', 'CANCELADO'));
  END IF;
END $$;

-- 3. Atualizar v_tasks_apoios_situacao para que vínculos não confirmados NÃO componham cobertura
CREATE OR REPLACE VIEW public.v_tasks_apoios_situacao AS
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
  WHERE v.ativo = true
    AND v.solicitacao_id IS NOT NULL
    AND v.status_confirmacao = 'CONFIRMADO'
),
agregado_por_solicitacao AS (
  SELECT
    s_1.id AS solicitacao_id,
    count(va.vinculo_id)::integer AS qtd_vinculos_ativos,
    count(va.vinculo_id) FILTER (
      WHERE upper(TRIM(BOTH FROM COALESCE(va.task_apoio_status, ''::character varying))) = 'CONC'::text
    )::integer AS qtd_concluidos,
    count(va.vinculo_id) FILTER (
      WHERE upper(TRIM(BOTH FROM COALESCE(va.task_apoio_status, ''::character varying))) = 'ANDA'::text
    )::integer AS qtd_andamento,
    count(va.vinculo_id) FILTER (
      WHERE upper(TRIM(BOTH FROM COALESCE(va.task_apoio_status, ''::character varying))) = 'CANC'::text
    )::integer AS qtd_cancelados,
    count(va.vinculo_id) FILTER (
      WHERE (upper(TRIM(BOTH FROM COALESCE(va.task_apoio_status, ''::character varying))) <> ALL (ARRAY['CANC'::text, ''::text]))
        AND (
          va.task_apoio_inicio > COALESCE(s_1.data_inicio_acordada, s_1.data_inicio_solicitada)
          OR va.task_apoio_fim < COALESCE(s_1.data_fim_acordada, s_1.data_fim_solicitada)
        )
    )::integer AS qtd_incompativeis,
    min(va.task_apoio_inicio) AS menor_inicio_programado,
    max(va.task_apoio_fim) AS maior_fim_programado
  FROM public.tasks_apoios_solicitacoes s_1
  LEFT JOIN vinculos_ativos va ON va.solicitacao_id = s_1.id
  GROUP BY s_1.id
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
    WHEN s.status::text = 'CANCELADA'::text THEN 'CANCELADO'::text
    WHEN s.status::text = 'RECUSADA'::text THEN 'RECUSADO'::text
    WHEN s.status::text = 'PENDENTE'::text THEN 'SOLICITADO'::text
    WHEN s.status::text = ANY (ARRAY['EM_ANALISE'::character varying, 'CONTRAPROPOSTA'::character varying]::text[]) THEN 'EM_NEGOCIACAO'::text
    WHEN s.status::text = 'ACEITA'::text AND ag.qtd_vinculos_ativos = 0 THEN 'ACEITO_NAO_PROGRAMADO'::text
    WHEN ag.qtd_vinculos_ativos > 0 AND ag.qtd_concluidos = ag.qtd_vinculos_ativos THEN 'CONCLUIDO'::text
    WHEN ag.qtd_vinculos_ativos > 0 AND ag.qtd_andamento > 0 THEN 'EM_ANDAMENTO'::text
    WHEN ag.qtd_vinculos_ativos > 0 AND ag.qtd_incompativeis > 0 THEN 'PROGRAMADO_INCOMPATIVEL'::text
    WHEN ag.qtd_vinculos_ativos > 0 AND (
      ag.menor_inicio_programado > COALESCE(s.data_inicio_acordada, s.data_inicio_solicitada)
      OR ag.maior_fim_programado < COALESCE(s.data_fim_acordada, s.data_fim_solicitada)
    ) THEN 'PROGRAMADO_PARCIAL'::text
    WHEN ag.qtd_vinculos_ativos > 0 THEN 'PROGRAMADO_COMPATIVEL'::text
    ELSE 'SOLICITADO'::text
  END AS situacao_operacional
FROM public.tasks_apoios_solicitacoes s
JOIN public.tasks_apoios_tipos tp ON tp.id = s.tipo_apoio_id
JOIN agregado_por_solicitacao ag ON ag.solicitacao_id = s.id;

COMMIT;

