-- ==============================================================================
-- MIGRATION: 20261016_notas_sap_grupos.sql
-- DESCRIÇÃO: Módulo de Vínculo entre Notas SAP e Previsão Macro de Programação
-- REQUISITOS:
--   1. Vínculo humano estruturado (notas_sap_grupos e notas_sap_grupos_itens).
--   2. Previsão macro em mês/ano numérico (não bloqueante, sem data fictícia).
--   3. Histórico de alterações e remoções de previsão (notas_sap_grupos_previsoes_hist).
--   4. Regra de unicidade: Uma Nota SAP só pode participar de 1 grupo ATIVO por vez.
--   5. Desacoplamento estrito: Programação real é consultada em tasks_notas_sap.
--   6. Índice idx_notas_sap_equipamento para funil de busca de similaridade.
-- ==============================================================================

-- 0. ÍNDICE DE PERFORMANCE IDENTIFICADO NO CHECKPOINT ANTERIOR
CREATE INDEX IF NOT EXISTS idx_notas_sap_equipamento ON public.notas_sap(equipamento);

-- ------------------------------------------------------------------------------
-- 1. TABELA PRINCIPAL DE GRUPOS DE NOTAS SAP
-- ------------------------------------------------------------------------------
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
COMMENT ON COLUMN public.notas_sap_grupos.status_grupo IS 'Status administrativo do grupo (ativo, encerrado, cancelado). Programação é derivada dinamicamente.';

-- ------------------------------------------------------------------------------
-- 2. TABELA ASSOCIATIVA DE ITENS DO GRUPO (1 GRUPO : N NOTAS SAP)
-- ------------------------------------------------------------------------------
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

COMMENT ON TABLE public.notas_sap_grupos_itens IS 'Vínculo das Notas SAP pertencentes a um grupo. Não duplica tarefa_id; programação é consultada em tasks_notas_sap.';

-- ------------------------------------------------------------------------------
-- 3. TABELA DE HISTÓRICO DE ALTERAÇÃO E REMOÇÃO DE PREVISÕES
-- ------------------------------------------------------------------------------
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

COMMENT ON TABLE public.notas_sap_grupos_previsoes_hist IS 'Histórico cronológico de alterações e remoções de previsão macro para medição de reprogramações';

-- ------------------------------------------------------------------------------
-- 4. TRIGGERS DE INTEGRIDADE E AUDITORIA
-- ------------------------------------------------------------------------------

-- 4.1. Atualização do updated_at
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

-- 4.2. REGRA DE NEGÓCIO: UMA NOTA PARTICIPA DE APENAS UM GRUPO ATIVO POR VEZ
CREATE OR REPLACE FUNCTION public.check_nota_em_grupo_ativo()
RETURNS TRIGGER AS $$
DECLARE
  v_grupo_status VARCHAR(30);
  v_outro_grupo_id UUID;
  v_outro_grupo_nome VARCHAR(255);
BEGIN
  -- Consultar status do grupo receptor
  SELECT status_grupo INTO v_grupo_status FROM public.notas_sap_grupos WHERE id = NEW.grupo_id;

  -- Se o grupo for ativo, verificar se a nota já está em outro grupo ativo
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

-- 4.3. REGRA DE REATIVAÇÃO DE GRUPO: Não permitir reativar grupo se contiver nota em outro grupo ativo
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

-- 4.4. REGISTRO AUTOMÁTICO DE HISTÓRICO DE PREVISÃO
CREATE OR REPLACE FUNCTION public.handle_historico_previsao_grupo()
RETURNS TRIGGER AS $$
BEGIN
  -- Dispara somente quando houver alteração efetiva de mês ou ano
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

-- ------------------------------------------------------------------------------
-- 5. HABILITAR ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.notas_sap_grupos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_grupos_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_grupos_previsoes_hist ENABLE ROW LEVEL SECURITY;

-- Políticas de notas_sap_grupos
DROP POLICY IF EXISTS "Grupos de notas visíveis para todos os usuários autenticados" ON public.notas_sap_grupos;
CREATE POLICY "Grupos de notas visíveis para todos os usuários autenticados" ON public.notas_sap_grupos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários autenticados podem gerenciar grupos de notas" ON public.notas_sap_grupos;
CREATE POLICY "Usuários autenticados podem gerenciar grupos de notas" ON public.notas_sap_grupos
  FOR ALL USING (true) WITH CHECK (true);

-- Políticas de notas_sap_grupos_itens
DROP POLICY IF EXISTS "Itens de grupos de notas visíveis para todos" ON public.notas_sap_grupos_itens;
CREATE POLICY "Itens de grupos de notas visíveis para todos" ON public.notas_sap_grupos_itens
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários autenticados podem gerenciar itens de grupos de notas" ON public.notas_sap_grupos_itens;
CREATE POLICY "Usuários autenticados podem gerenciar itens de grupos de notas" ON public.notas_sap_grupos_itens
  FOR ALL USING (true) WITH CHECK (true);

-- Políticas de notas_sap_grupos_previsoes_hist
DROP POLICY IF EXISTS "Histórico de previsões visível para todos" ON public.notas_sap_grupos_previsoes_hist;
CREATE POLICY "Histórico de previsões visível para todos" ON public.notas_sap_grupos_previsoes_hist
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários autenticados podem registrar histórico de previsões" ON public.notas_sap_grupos_previsoes_hist;
CREATE POLICY "Usuários autenticados podem registrar histórico de previsões" ON public.notas_sap_grupos_previsoes_hist
  FOR ALL USING (true) WITH CHECK (true);

-- ------------------------------------------------------------------------------
-- 6. RECARREGAR SCHEMA DO POSTGREST
-- ------------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
