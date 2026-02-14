-- ============================================
-- Módulo Melhorias e Bugs - TaskFlow
-- Entidades: versoes, melhorias_bugs (status humanizados)
-- ============================================

-- Função updated_at
CREATE OR REPLACE FUNCTION public.melhorias_bugs_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now() AT TIME ZONE 'utc';
  RETURN NEW;
END;
$$;

-- ------------------------------
-- versoes (roadmap de versões)
-- ------------------------------
CREATE TABLE IF NOT EXISTS public.versoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome TEXT NOT NULL,
  descricao TEXT,
  data_prevista_lancamento DATE,
  data_lancamento DATE,
  ordem INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

CREATE INDEX IF NOT EXISTS idx_versoes_ordem ON public.versoes(ordem);
CREATE INDEX IF NOT EXISTS idx_versoes_data_prevista ON public.versoes(data_prevista_lancamento);

DROP TRIGGER IF EXISTS versoes_updated_at ON public.versoes;
CREATE TRIGGER versoes_updated_at
  BEFORE UPDATE ON public.versoes
  FOR EACH ROW EXECUTE FUNCTION public.melhorias_bugs_updated_at();

COMMENT ON TABLE public.versoes IS 'Roadmap de versões do produto (TaskFlow).';

-- ------------------------------
-- melhorias_bugs
-- Status: BACKLOG, ANALISE, DESENVOLVIMENTO, VALIDACAO, CONCLUIDO, REABERTO, REJEITADO, DUPLICADO
-- ------------------------------
CREATE TABLE IF NOT EXISTS public.melhorias_bugs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo TEXT NOT NULL CHECK (tipo IN ('BUG', 'MELHORIA')),
  titulo TEXT NOT NULL,
  descricao TEXT,
  status TEXT NOT NULL DEFAULT 'BACKLOG' CHECK (status IN (
    'BACKLOG', 'ANALISE', 'DESENVOLVIMENTO', 'VALIDACAO', 'CONCLUIDO', 'REABERTO', 'REJEITADO', 'DUPLICADO'
  )),
  versao_id UUID REFERENCES public.versoes(id) ON DELETE SET NULL,
  prioridade TEXT CHECK (prioridade IN ('BAIXA', 'MEDIA', 'ALTA', 'CRITICA')),
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  concluido_em TIMESTAMPTZ,
  reaberto_em TIMESTAMPTZ,
  versao_corrigida TEXT
);

CREATE INDEX IF NOT EXISTS idx_melhorias_bugs_status ON public.melhorias_bugs(status);
CREATE INDEX IF NOT EXISTS idx_melhorias_bugs_tipo ON public.melhorias_bugs(tipo);
CREATE INDEX IF NOT EXISTS idx_melhorias_bugs_versao_id ON public.melhorias_bugs(versao_id);
CREATE INDEX IF NOT EXISTS idx_melhorias_bugs_created_at ON public.melhorias_bugs(created_at);
CREATE INDEX IF NOT EXISTS idx_melhorias_bugs_updated_at ON public.melhorias_bugs(updated_at);
CREATE INDEX IF NOT EXISTS idx_melhorias_bugs_concluido_em ON public.melhorias_bugs(concluido_em);

DROP TRIGGER IF EXISTS melhorias_bugs_updated_at ON public.melhorias_bugs;
CREATE TRIGGER melhorias_bugs_updated_at
  BEFORE UPDATE ON public.melhorias_bugs
  FOR EACH ROW EXECUTE FUNCTION public.melhorias_bugs_updated_at();

COMMENT ON TABLE public.melhorias_bugs IS 'Bugs e melhorias do produto TaskFlow (evolução do sistema).';

-- ------------------------------
-- VIEW: Bugs e melhorias por versão (uma linha por versão)
-- ------------------------------
CREATE OR REPLACE VIEW public.v_melhorias_bugs_por_versao AS
SELECT
  v.id AS versao_id,
  v.nome AS versao_nome,
  v.data_prevista_lancamento,
  v.data_lancamento,
  COUNT(mb.id) FILTER (WHERE mb.tipo = 'BUG') AS total_bugs,
  COUNT(mb.id) FILTER (WHERE mb.tipo = 'MELHORIA') AS total_melhorias,
  COUNT(mb.id) FILTER (WHERE mb.status = 'CONCLUIDO') AS concluidos,
  COUNT(mb.id) FILTER (WHERE mb.status NOT IN ('CONCLUIDO', 'REJEITADO', 'DUPLICADO')) AS em_aberto
FROM public.versoes v
LEFT JOIN public.melhorias_bugs mb ON mb.versao_id = v.id
GROUP BY v.id, v.nome, v.data_prevista_lancamento, v.data_lancamento;

-- Vista consolidada por versão (uma linha por versão)
CREATE OR REPLACE VIEW public.v_versoes_resumo AS
SELECT
  v.id,
  v.nome,
  v.descricao,
  v.data_prevista_lancamento,
  v.data_lancamento,
  v.ordem,
  v.created_at,
  v.updated_at,
  COUNT(mb.id) AS total_itens,
  COUNT(mb.id) FILTER (WHERE mb.status = 'CONCLUIDO') AS concluidos,
  COUNT(mb.id) FILTER (WHERE mb.tipo = 'BUG' AND mb.status = 'CONCLUIDO') AS bugs_concluidos,
  COUNT(mb.id) FILTER (WHERE mb.tipo = 'MELHORIA' AND mb.status = 'CONCLUIDO') AS melhorias_concluidas,
  COUNT(mb.id) FILTER (WHERE mb.status NOT IN ('CONCLUIDO', 'REJEITADO', 'DUPLICADO')) AS em_aberto
FROM public.versoes v
LEFT JOIN public.melhorias_bugs mb ON mb.versao_id = v.id
GROUP BY v.id, v.nome, v.descricao, v.data_prevista_lancamento, v.data_lancamento, v.ordem, v.created_at, v.updated_at
ORDER BY v.ordem, v.data_prevista_lancamento NULLS LAST;

-- ------------------------------
-- VIEW: MTTR (tempo médio de correção) - apenas itens concluídos com created_at e concluido_em
-- ------------------------------
CREATE OR REPLACE VIEW public.v_melhorias_bugs_mttr AS
SELECT
  mb.tipo,
  mb.versao_id,
  v.nome AS versao_nome,
  COUNT(*) AS quantidade,
  EXTRACT(EPOCH FROM AVG(mb.concluido_em - mb.created_at)) / 86400 AS mttr_dias_medio
FROM public.melhorias_bugs mb
LEFT JOIN public.versoes v ON v.id = mb.versao_id
WHERE mb.status = 'CONCLUIDO' AND mb.concluido_em IS NOT NULL AND mb.created_at IS NOT NULL
GROUP BY mb.tipo, mb.versao_id, v.nome;

-- ------------------------------
-- VIEW: Taxa de reabertura (itens que têm reaberto_em preenchido)
-- ------------------------------
CREATE OR REPLACE VIEW public.v_melhorias_bugs_taxa_reabertura AS
SELECT
  COUNT(*) FILTER (WHERE reaberto_em IS NOT NULL) AS total_reabertos,
  COUNT(*) AS total_concluidos_ou_reabertos,
  CASE
    WHEN COUNT(*) = 0 THEN 0
    ELSE 100.0 * COUNT(*) FILTER (WHERE reaberto_em IS NOT NULL) / NULLIF(COUNT(*), 0)
  END AS taxa_reabertura_pct
FROM public.melhorias_bugs
WHERE status IN ('CONCLUIDO', 'REABERTO');

-- ------------------------------
-- VIEW: Backlog ativo por status
-- ------------------------------
CREATE OR REPLACE VIEW public.v_melhorias_bugs_backlog_status AS
SELECT
  status,
  tipo,
  COUNT(*) AS quantidade
FROM public.melhorias_bugs
WHERE status NOT IN ('CONCLUIDO', 'REJEITADO', 'DUPLICADO')
GROUP BY status, tipo
ORDER BY status, tipo;

-- ------------------------------
-- VIEW: Throughput (itens concluídos por período - por mês)
-- ------------------------------
CREATE OR REPLACE VIEW public.v_melhorias_bugs_throughput_mes AS
SELECT
  DATE_TRUNC('month', concluido_em AT TIME ZONE 'utc')::DATE AS mes,
  tipo,
  COUNT(*) AS concluidos
FROM public.melhorias_bugs
WHERE status = 'CONCLUIDO' AND concluido_em IS NOT NULL
GROUP BY DATE_TRUNC('month', concluido_em AT TIME ZONE 'utc'), tipo
ORDER BY mes DESC, tipo;

-- Throughput por semana (últimos 12 semanas úteis)
CREATE OR REPLACE VIEW public.v_melhorias_bugs_throughput_semana AS
SELECT
  DATE_TRUNC('week', concluido_em AT TIME ZONE 'utc')::DATE AS semana_inicio,
  tipo,
  COUNT(*) AS concluidos
FROM public.melhorias_bugs
WHERE status = 'CONCLUIDO' AND concluido_em IS NOT NULL
GROUP BY DATE_TRUNC('week', concluido_em AT TIME ZONE 'utc'), tipo
ORDER BY semana_inicio DESC;
