-- ==============================================================================
-- ETAPA 2: Grupos de Notas SAP e Previsão Macro de Programação
-- ARQUIVO: 02_grupos_previsao.sql
-- AMBIENTE: Produção (10.140.50.12)
-- DIRETRIZES: Idempotente (IF NOT EXISTS), sem operações destrutivas.
-- ==============================================================================

\set ON_ERROR_STOP 1

BEGIN;

-- 1. ÍNDICE DE PERFORMANCE EM NOTAS SAP
CREATE INDEX IF NOT EXISTS idx_notas_sap_equipamento ON public.notas_sap(equipamento);

-- 2. TABELA PRINCIPAL DE GRUPOS DE NOTAS SAP
CREATE TABLE IF NOT EXISTS public.notas_sap_grupos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome VARCHAR(255) NOT NULL,
  descricao TEXT,
  motivo TEXT,

  -- Contexto opcional (herdado ou definido)
  local_instalacao VARCHAR(255),
  equipamento VARCHAR(50),
  centro_trabalho_responsavel VARCHAR(50),

  -- PREVISÃO MACRO DE PROGRAMAÇÃO (Opcional, Não Bloqueante)
  mes_programacao_previsto INTEGER,
  ano_programacao_previsto INTEGER,
  motivo_previsao TEXT,

  -- Status Administrativo do Grupo
  status_grupo VARCHAR(30) NOT NULL DEFAULT 'ativo'
    CHECK (status_grupo IN ('ativo', 'encerrado', 'cancelado')),

  -- Auditoria de Criação
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Auditoria da Previsão
  previsao_alterada_em TIMESTAMPTZ,
  previsao_alterada_por UUID,
  previsao_alterada_por_nome VARCHAR(255),

  -- CONSTRAINTS
  CONSTRAINT chk_notas_grupos_mes CHECK (mes_programacao_previsto BETWEEN 1 AND 12),
  CONSTRAINT chk_notas_grupos_ano CHECK (ano_programacao_previsto BETWEEN 2020 AND 2100),
  CONSTRAINT chk_notas_grupos_paridade_mes_ano CHECK (
    (mes_programacao_previsto IS NULL AND ano_programacao_previsto IS NULL) OR
    (mes_programacao_previsto IS NOT NULL AND ano_programacao_previsto IS NOT NULL)
  )
);

-- Índices de notas_sap_grupos
CREATE INDEX IF NOT EXISTS idx_notas_sap_grupos_status ON public.notas_sap_grupos(status_grupo);
CREATE INDEX IF NOT EXISTS idx_notas_sap_grupos_previsao ON public.notas_sap_grupos(ano_programacao_previsto, mes_programacao_previsto);
CREATE INDEX IF NOT EXISTS idx_notas_sap_grupos_eq ON public.notas_sap_grupos(equipamento);
CREATE INDEX IF NOT EXISTS idx_notas_sap_grupos_loc ON public.notas_sap_grupos(local_instalacao);

COMMENT ON TABLE public.notas_sap_grupos IS 'Grupos de Notas SAP organizadas para futura programação conjunta com previsão macro';
COMMENT ON COLUMN public.notas_sap_grupos.mes_programacao_previsto IS 'Mês numérico previsto para programação (1 a 12). Sem datas fictícias.';
COMMENT ON COLUMN public.notas_sap_grupos.status_grupo IS 'Status administrativo do grupo (ativo, encerrado, cancelado).';

-- 3. TABELA ASSOCIATIVA DE ITENS DO GRUPO (1 GRUPO : N NOTAS SAP)
CREATE TABLE IF NOT EXISTS public.notas_sap_grupos_itens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grupo_id UUID NOT NULL REFERENCES public.notas_sap_grupos(id) ON DELETE CASCADE,
  nota_sap_id UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  motivo_vinculo TEXT,
  
  adicionado_por UUID,
  adicionado_por_nome VARCHAR(255),
  adicionado_em TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT uq_grupo_nota UNIQUE (grupo_id, nota_sap_id)
);

-- Índices de notas_sap_grupos_itens
CREATE INDEX IF NOT EXISTS idx_notas_sap_grupos_itens_grupo ON public.notas_sap_grupos_itens(grupo_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_grupos_itens_nota ON public.notas_sap_grupos_itens(nota_sap_id);

COMMENT ON TABLE public.notas_sap_grupos_itens IS 'Vínculo das Notas SAP pertencentes a um grupo.';

-- 4. TABELA DE HISTÓRICO DE PREVISÕES
CREATE TABLE IF NOT EXISTS public.notas_sap_grupos_previsoes_hist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grupo_id UUID NOT NULL REFERENCES public.notas_sap_grupos(id) ON DELETE CASCADE,
  mes_anterior INTEGER,
  ano_anterior INTEGER,
  mes_novo INTEGER,
  ano_novo INTEGER,
  motivo TEXT,
  alterado_por UUID,
  alterado_por_nome VARCHAR(255),
  alterado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notas_sap_grupos_hist_grupo ON public.notas_sap_grupos_previsoes_hist(grupo_id);

COMMENT ON TABLE public.notas_sap_grupos_previsoes_hist IS 'Histórico cronológico de alterações e remoções de previsão macro';

-- 5. FUNÇÕES E TRIGGERS DE INTEGRIDADE
CREATE OR REPLACE FUNCTION public.handle_updated_at_notas_grupos()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notas_sap_grupos_updated ON public.notas_sap_grupos;
CREATE TRIGGER trigger_notas_sap_grupos_updated
  BEFORE UPDATE ON public.notas_sap_grupos
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_notas_grupos();

-- Regra: Uma nota em apenas um grupo ativo por vez
CREATE OR REPLACE FUNCTION public.check_nota_em_grupo_ativo()
RETURNS TRIGGER AS $$
DECLARE
  v_grupo_status VARCHAR(30);
  v_outro_grupo_id UUID;
  v_outro_grupo_nome VARCHAR(255);
BEGIN
  SELECT status_grupo INTO v_grupo_status FROM public.notas_sap_grupos WHERE id = NEW.grupo_id;

  IF v_grupo_status = 'ativo' THEN
    SELECT g.id, g.nome INTO v_outro_grupo_id, v_outro_grupo_nome
    FROM public.notas_sap_grupos_itens i
    JOIN public.notas_sap_grupos g ON g.id = i.grupo_id
    WHERE i.nota_sap_id = NEW.nota_sap_id
      AND g.status_grupo = 'ativo'
      AND g.id <> NEW.grupo_id
    LIMIT 1;

    IF v_outro_grupo_id IS NOT NULL THEN
      RAISE EXCEPTION 'A Nota SAP já pertence ao grupo ativo "%" (ID: %). Uma Nota não pode participar de dois grupos ativos simultaneamente.',
        v_outro_grupo_nome, v_outro_grupo_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_nota_em_grupo_ativo ON public.notas_sap_grupos_itens;
CREATE TRIGGER trigger_check_nota_em_grupo_ativo
  BEFORE INSERT OR UPDATE ON public.notas_sap_grupos_itens
  FOR EACH ROW
  EXECUTE FUNCTION public.check_nota_em_grupo_ativo();

-- Regra de reativação de grupo
CREATE OR REPLACE FUNCTION public.check_reativacao_grupo()
RETURNS TRIGGER AS $$
DECLARE
  v_conflito RECORD;
BEGIN
  IF NEW.status_grupo = 'ativo' AND (OLD.status_grupo <> 'ativo' OR OLD.status_grupo IS NULL) THEN
    SELECT i.nota_sap_id, g2.nome as outro_nome, g2.id as outro_id INTO v_conflito
    FROM public.notas_sap_grupos_itens i
    JOIN public.notas_sap_grupos_itens i2 ON i2.nota_sap_id = i.nota_sap_id AND i2.grupo_id <> NEW.id
    JOIN public.notas_sap_grupos g2 ON g2.id = i2.grupo_id AND g2.status_grupo = 'ativo'
    WHERE i.grupo_id = NEW.id
    LIMIT 1;

    IF v_conflito IS NOT NULL THEN
      RAISE EXCEPTION 'Não é possível reativar o grupo: a Nota % já pertence ao grupo ativo "%".',
        v_conflito.nota_sap_id, v_conflito.outro_nome;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_reativacao_grupo ON public.notas_sap_grupos;
CREATE TRIGGER trigger_check_reativacao_grupo
  BEFORE UPDATE OF status_grupo ON public.notas_sap_grupos
  FOR EACH ROW
  EXECUTE FUNCTION public.check_reativacao_grupo();

-- Histórico de previsão automático
CREATE OR REPLACE FUNCTION public.handle_historico_previsao_grupo()
RETURNS TRIGGER AS $$
BEGIN
  IF (OLD.mes_programacao_previsto, OLD.ano_programacao_previsto) IS DISTINCT FROM (NEW.mes_programacao_previsto, NEW.ano_programacao_previsto) THEN
    INSERT INTO public.notas_sap_grupos_previsoes_hist (
      grupo_id,
      mes_anterior,
      ano_anterior,
      mes_novo,
      ano_novo,
      motivo,
      alterado_por,
      alterado_por_nome,
      alterado_em
    ) VALUES (
      NEW.id,
      OLD.mes_programacao_previsto,
      OLD.ano_programacao_previsto,
      NEW.mes_programacao_previsto,
      NEW.ano_programacao_previsto,
      NEW.motivo_previsao,
      NEW.previsao_alterada_por,
      NEW.previsao_alterada_por_nome,
      NOW()
    );

    NEW.previsao_alterada_em = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_historico_previsao_grupo ON public.notas_sap_grupos;
CREATE TRIGGER trigger_historico_previsao_grupo
  BEFORE UPDATE ON public.notas_sap_grupos
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_historico_previsao_grupo();

-- 6. HABILITAR ROW LEVEL SECURITY (RLS)
ALTER TABLE public.notas_sap_grupos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_grupos_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_grupos_previsoes_hist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Grupos de notas visíveis para todos os usuários autenticados" ON public.notas_sap_grupos;
CREATE POLICY "Grupos de notas visíveis para todos os usuários autenticados" ON public.notas_sap_grupos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários autenticados podem gerenciar grupos de notas" ON public.notas_sap_grupos;
CREATE POLICY "Usuários autenticados podem gerenciar grupos de notas" ON public.notas_sap_grupos
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Itens de grupos de notas visíveis para todos" ON public.notas_sap_grupos_itens;
CREATE POLICY "Itens de grupos de notas visíveis para todos" ON public.notas_sap_grupos_itens
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários autenticados podem gerenciar itens de grupos de notas" ON public.notas_sap_grupos_itens;
CREATE POLICY "Usuários autenticados podem gerenciar itens de grupos de notas" ON public.notas_sap_grupos_itens
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Histórico de previsões visível para todos" ON public.notas_sap_grupos_previsoes_hist;
CREATE POLICY "Histórico de previsões visível para todos" ON public.notas_sap_grupos_previsoes_hist
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários autenticados podem registrar histórico de previsões" ON public.notas_sap_grupos_previsoes_hist;
CREATE POLICY "Usuários autenticados podem registrar histórico de previsões" ON public.notas_sap_grupos_previsoes_hist
  FOR ALL USING (true) WITH CHECK (true);

-- 7. CONCESSÃO DE PRIVILÉGIOS (GRANTS PARA API SUPABASE)
DO $$
BEGIN
  GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_grupos TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_grupos_itens TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_grupos_previsoes_hist TO anon, authenticated, service_role;
END $$;

COMMIT;
