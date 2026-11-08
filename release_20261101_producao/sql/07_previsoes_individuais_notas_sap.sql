-- ==============================================================================
-- MIGRATION: 20261102_previsoes_individuais_notas_sap.sql
-- DESCRIÇÃO: Gestão Ativa de Previsibilidade de Notas SAP Individuais e em Lote
--            com Rastreabilidade, Histórico de Reprogramação e Suporte a Rollback
-- ==============================================================================

-- 1. TABELA PRINCIPAL DE PREVISÕES INDIVIDUAIS DE NOTAS SAP
CREATE TABLE IF NOT EXISTS public.notas_sap_previsoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_sap_id UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  numero_nota TEXT,
  mes_previsao INTEGER NOT NULL CHECK (mes_previsao BETWEEN 1 AND 12),
  ano_previsao INTEGER NOT NULL CHECK (ano_previsao >= 2020),
  motivo_previsao TEXT,
  lote_id UUID, -- Identificador de lote quando atribuído em massa
  criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  criado_por UUID,
  criado_por_nome TEXT,
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_por UUID,
  atualizado_por_nome TEXT,
  CONSTRAINT uq_notas_sap_previsoes_nota UNIQUE (nota_sap_id)
);

-- Índices de performance
CREATE INDEX IF NOT EXISTS idx_notas_sap_previsoes_nota_id 
  ON public.notas_sap_previsoes(nota_sap_id);

CREATE INDEX IF NOT EXISTS idx_notas_sap_previsoes_mes_ano 
  ON public.notas_sap_previsoes(ano_previsao, mes_previsao);

CREATE INDEX IF NOT EXISTS idx_notas_sap_previsoes_lote 
  ON public.notas_sap_previsoes(lote_id) WHERE lote_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notas_sap_previsoes_numero 
  ON public.notas_sap_previsoes(numero_nota);

COMMENT ON TABLE public.notas_sap_previsoes IS 
'Fonte da verdade para previsão tática de atendimento de notas SAP que ainda não possuem grupo ou possuem previsão individual customizada';

-- 2. TABELA DE HISTÓRICO DE AUDITORIA E REPROGRAMAÇÕES (Para rollback e aderência)
CREATE TABLE IF NOT EXISTS public.notas_sap_previsoes_hist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  previsao_id UUID REFERENCES public.notas_sap_previsoes(id) ON DELETE SET NULL,
  nota_sap_id UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  numero_nota TEXT,
  mes_anterior INTEGER,
  ano_anterior INTEGER,
  mes_novo INTEGER,
  ano_novo INTEGER,
  motivo TEXT,
  operacao TEXT NOT NULL DEFAULT 'ATRIBUICAO_INDIVIDUAL', -- 'ATRIBUICAO_INDIVIDUAL', 'ATRIBUICAO_LOTE', 'DESFEITO_LOTE', 'LIMPEZA'
  lote_id UUID,
  alterado_por UUID,
  alterado_por_nome TEXT,
  alterado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices de histórico
CREATE INDEX IF NOT EXISTS idx_notas_sap_previsoes_hist_nota 
  ON public.notas_sap_previsoes_hist(nota_sap_id);

CREATE INDEX IF NOT EXISTS idx_notas_sap_previsoes_hist_lote 
  ON public.notas_sap_previsoes_hist(lote_id) WHERE lote_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notas_sap_previsoes_hist_data 
  ON public.notas_sap_previsoes_hist(alterado_em DESC);

COMMENT ON TABLE public.notas_sap_previsoes_hist IS 
'Trilha de auditoria das reprogramações e previsões atribuídas às notas, permitindo desfazer lotes e analisar aderência';

-- 3. TRIGGER PARA ATUALIZAR TIMESTAMP DE MODIFICAÇÃO
CREATE OR REPLACE FUNCTION public.handle_updated_at_previsao_nota()
RETURNS TRIGGER AS $$
BEGIN
  NEW.atualizado_em = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_previsao_nota_updated ON public.notas_sap_previsoes;
CREATE TRIGGER trigger_previsao_nota_updated
  BEFORE UPDATE ON public.notas_sap_previsoes
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_previsao_nota();

-- 4. TRIGGER PARA CAPTURA AUTOMÁTICA DE HISTÓRICO NA ATUALIZAÇÃO
CREATE OR REPLACE FUNCTION public.handle_historico_previsao_nota()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN
    IF (OLD.mes_previsao, OLD.ano_previsao) IS DISTINCT FROM (NEW.mes_previsao, NEW.ano_previsao) THEN
      INSERT INTO public.notas_sap_previsoes_hist (
        previsao_id,
        nota_sap_id,
        numero_nota,
        mes_anterior,
        ano_anterior,
        mes_novo,
        ano_novo,
        motivo,
        operacao,
        lote_id,
        alterado_por,
        alterado_por_nome,
        alterado_em
      ) VALUES (
        NEW.id,
        NEW.nota_sap_id,
        NEW.numero_nota,
        OLD.mes_previsao,
        OLD.ano_previsao,
        NEW.mes_previsao,
        NEW.ano_previsao,
        NEW.motivo_previsao,
        COALESCE(NEW.motivo_previsao, 'REPROGRAMACAO'),
        NEW.lote_id,
        NEW.atualizado_por,
        NEW.atualizado_por_nome,
        NOW()
      );
    END IF;
  ELSIF (TG_OP = 'INSERT') THEN
    INSERT INTO public.notas_sap_previsoes_hist (
      previsao_id,
      nota_sap_id,
      numero_nota,
      mes_anterior,
      ano_anterior,
      mes_novo,
      ano_novo,
      motivo,
      operacao,
      lote_id,
      alterado_por,
      alterado_por_nome,
      alterado_em
    ) VALUES (
      NEW.id,
      NEW.nota_sap_id,
      NEW.numero_nota,
      NULL,
      NULL,
      NEW.mes_previsao,
      NEW.ano_previsao,
      NEW.motivo_previsao,
      CASE WHEN NEW.lote_id IS NOT NULL THEN 'ATRIBUICAO_LOTE' ELSE 'ATRIBUICAO_INDIVIDUAL' END,
      NEW.lote_id,
      NEW.criado_por,
      NEW.criado_por_nome,
      NOW()
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_historico_previsao_nota ON public.notas_sap_previsoes;
CREATE TRIGGER trigger_historico_previsao_nota
  AFTER INSERT OR UPDATE ON public.notas_sap_previsoes
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_historico_previsao_nota();

-- 5. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.notas_sap_previsoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_previsoes_hist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Previsões de notas visíveis para todos os autenticados" ON public.notas_sap_previsoes;
CREATE POLICY "Previsões de notas visíveis para todos os autenticados" ON public.notas_sap_previsoes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários autenticados podem gerenciar previsões de notas" ON public.notas_sap_previsoes;
CREATE POLICY "Usuários autenticados podem gerenciar previsões de notas" ON public.notas_sap_previsoes
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Histórico de previsões visível para todos os autenticados" ON public.notas_sap_previsoes_hist;
CREATE POLICY "Histórico de previsões visível para todos os autenticados" ON public.notas_sap_previsoes_hist
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Inserção no histórico de previsões permitido" ON public.notas_sap_previsoes_hist;
CREATE POLICY "Inserção no histórico de previsões permitido" ON public.notas_sap_previsoes_hist
  FOR ALL USING (true) WITH CHECK (true);

-- Notificar PostgREST para recarregar schema
NOTIFY pgrst, 'reload schema';
