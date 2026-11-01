-- ==============================================================================
-- ETAPA 1: Pré-requisitos e Análise Prévia de Notas SAP
-- ARQUIVO: 01_pre_requisitos_e_analise_base.sql
-- AMBIENTE: Produção (10.140.50.12)
-- DIRETRIZES: Idempotente (IF NOT EXISTS), sem operações destrutivas.
-- ==============================================================================

\set ON_ERROR_STOP 1

BEGIN;

-- 1. VALIDAÇÃO DE PRÉ-REQUISITOS ESSENCIAIS
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notas_sap') THEN
    RAISE EXCEPTION 'PRÉ-REQUISITO FALHOU: A tabela public.notas_sap não existe no banco de dados!';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'executores') THEN
    RAISE EXCEPTION 'PRÉ-REQUISITO FALHOU: A tabela public.executores não existe no banco de dados!';
  END IF;
  
  RAISE NOTICE 'PRÉ-REQUISITOS OK: tabelas base notas_sap e executores encontradas.';
END $$;

-- 2. TABELA PRINCIPAL DE ANÁLISE TÉCNICA (1:1 com notas_sap)
CREATE TABLE IF NOT EXISTS public.notas_sap_analises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_sap_id UUID NOT NULL UNIQUE REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  numero_nota VARCHAR(50),
  status_analise VARCHAR(30) NOT NULL DEFAULT 'nao_iniciada' 
    CHECK (status_analise IN ('nao_iniciada', 'em_analise', 'concluida', 'aguardando_informacao', 'cancelada')),
  diagnostico_previo TEXT,
  escopo_detalhado TEXT,
  observacoes_planejamento TEXT,
  necessita_desligamento BOOLEAN DEFAULT FALSE,
  necessita_bloqueio BOOLEAN DEFAULT FALSE,
  estimativa_horas NUMERIC(6,2),
  quantidade_tecnicos INTEGER,
  ferramentas_especiais TEXT,
  requisitos_seguranca TEXT,
  valor_pv NUMERIC(14,2), -- Parcela Variável estimada
  analista_id UUID REFERENCES public.executores(id) ON DELETE SET NULL,
  analista_nome VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Garantir coluna valor_pv caso a tabela já existisse sem ela
ALTER TABLE public.notas_sap_analises ADD COLUMN IF NOT EXISTS valor_pv NUMERIC(14,2);

-- Índices de notas_sap_analises
CREATE INDEX IF NOT EXISTS idx_notas_sap_analises_nota_id ON public.notas_sap_analises(nota_sap_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_analises_status ON public.notas_sap_analises(status_analise);
CREATE INDEX IF NOT EXISTS idx_notas_sap_analises_numero ON public.notas_sap_analises(numero_nota);

COMMENT ON TABLE public.notas_sap_analises IS 'Análises técnicas prévias elaboradas por analistas antes ou após a programação';
COMMENT ON COLUMN public.notas_sap_analises.status_analise IS 'Status informativo da análise (nunca bloqueante de programação)';
COMMENT ON COLUMN public.notas_sap_analises.valor_pv IS 'Valor financeiro estimado da Parcela Variável (PV) em caso de desligamento';

-- 3. TABELA DE MATERIAIS E PEÇAS DA ANÁLISE (1:N com notas_sap_analises)
CREATE TABLE IF NOT EXISTS public.notas_sap_analise_materiais (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_sap_id UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  analise_id UUID REFERENCES public.notas_sap_analises(id) ON DELETE CASCADE,
  codigo_sap VARCHAR(50),
  descricao TEXT NOT NULL,
  quantidade NUMERIC(10,2) NOT NULL DEFAULT 1,
  unidade VARCHAR(20) DEFAULT 'UN',
  status_material VARCHAR(30) NOT NULL DEFAULT 'nao_verificado'
    CHECK (status_material IN ('nao_verificado', 'disponivel', 'reservado', 'aguardando_material', 'aguardando_compra', 'substituido')),
  observacao TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices de notas_sap_analise_materiais
CREATE INDEX IF NOT EXISTS idx_notas_sap_materiais_nota_id ON public.notas_sap_analise_materiais(nota_sap_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_materiais_analise_id ON public.notas_sap_analise_materiais(analise_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_materiais_status ON public.notas_sap_analise_materiais(status_material);

COMMENT ON TABLE public.notas_sap_analise_materiais IS 'Peças e materiais necessários levantados na análise técnica da Nota';

-- 4. TABELA DE DISCUSSÃO TÉCNICA / COMENTÁRIOS DA NOTA (1:N com notas_sap)
CREATE TABLE IF NOT EXISTS public.notas_sap_comentarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_sap_id UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  usuario_id UUID NOT NULL,
  usuario_nome VARCHAR(255),
  mensagem TEXT NOT NULL,
  tipo_mensagem VARCHAR(20) DEFAULT 'texto' CHECK (tipo_mensagem IN ('texto', 'anexo_link', 'sistema')),
  reply_to_id UUID REFERENCES public.notas_sap_comentarios(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Índices de notas_sap_comentarios
CREATE INDEX IF NOT EXISTS idx_notas_sap_comentarios_nota_id ON public.notas_sap_comentarios(nota_sap_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_comentarios_created ON public.notas_sap_comentarios(created_at ASC);

COMMENT ON TABLE public.notas_sap_comentarios IS 'Timeline e chat técnico da Nota SAP antes ou após a programação';

-- 5. TRIGGERS DE ATUALIZAÇÃO AUTOMÁTICA DE updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at_notas_analise()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notas_sap_analises_updated ON public.notas_sap_analises;
CREATE TRIGGER trigger_notas_sap_analises_updated
  BEFORE UPDATE ON public.notas_sap_analises
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_notas_analise();

DROP TRIGGER IF EXISTS trigger_notas_sap_materiais_updated ON public.notas_sap_analise_materiais;
CREATE TRIGGER trigger_notas_sap_materiais_updated
  BEFORE UPDATE ON public.notas_sap_analise_materiais
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_notas_analise();

DROP TRIGGER IF EXISTS trigger_notas_sap_comentarios_updated ON public.notas_sap_comentarios;
CREATE TRIGGER trigger_notas_sap_comentarios_updated
  BEFORE UPDATE ON public.notas_sap_comentarios
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_notas_analise();

-- 6. HABILITAR ROW LEVEL SECURITY (RLS)
ALTER TABLE public.notas_sap_analises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_analise_materiais ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_comentarios ENABLE ROW LEVEL SECURITY;

-- Políticas de notas_sap_analises
DROP POLICY IF EXISTS "Análises são visíveis para todos" ON public.notas_sap_analises;
CREATE POLICY "Análises são visíveis para todos" ON public.notas_sap_analises
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários podem gerenciar análises" ON public.notas_sap_analises;
CREATE POLICY "Usuários podem gerenciar análises" ON public.notas_sap_analises
  FOR ALL USING (true) WITH CHECK (true);

-- Políticas de notas_sap_analise_materiais
DROP POLICY IF EXISTS "Materiais de análise visíveis para todos" ON public.notas_sap_analise_materiais;
CREATE POLICY "Materiais de análise visíveis para todos" ON public.notas_sap_analise_materiais
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários podem gerenciar materiais de análise" ON public.notas_sap_analise_materiais;
CREATE POLICY "Usuários podem gerenciar materiais de análise" ON public.notas_sap_analise_materiais
  FOR ALL USING (true) WITH CHECK (true);

-- Políticas de notas_sap_comentarios
DROP POLICY IF EXISTS "Comentários de notas visíveis para todos" ON public.notas_sap_comentarios;
CREATE POLICY "Comentários de notas visíveis para todos" ON public.notas_sap_comentarios
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários podem gerenciar comentários de notas" ON public.notas_sap_comentarios;
CREATE POLICY "Usuários podem gerenciar comentários de notas" ON public.notas_sap_comentarios
  FOR ALL USING (true) WITH CHECK (true);

-- 7. CONCESSÃO DE PRIVILÉGIOS (GRANTS PARA API SUPABASE)
DO $$
BEGIN
  GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_analises TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_analise_materiais TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_comentarios TO anon, authenticated, service_role;
END $$;

-- 8. REALTIME PARA COMENTÁRIOS DA NOTA
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'notas_sap_comentarios'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notas_sap_comentarios;
    END IF;
  END IF;
END $$;

COMMIT;
