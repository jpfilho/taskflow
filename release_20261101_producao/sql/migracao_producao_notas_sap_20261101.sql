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
-- ==============================================================================
-- ETAPA 3: Anexos das Notas SAP, Storage e Anotações Técnicas
-- ARQUIVO: 03_anexos_storage_e_anotacoes.sql
-- AMBIENTE: Produção (10.140.50.12)
-- DIRETRIZES: Idempotente (IF NOT EXISTS), sem operações destrutivas.
-- ==============================================================================

\set ON_ERROR_STOP 1

BEGIN;

-- 1. BUCKET NOVO 'notas-sap-anexos' NO STORAGE (PRIVADO)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'buckets') THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'notas-sap-anexos',
      'notas-sap-anexos',
      false,
      104857600, -- 100 MB
      NULL
    )
    ON CONFLICT (id) DO UPDATE 
    SET public = false;
  END IF;
END $$;

-- 2. POLÍTICAS DE RLS DO STORAGE
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'objects') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir leitura de notas-sap-anexos'
    ) THEN
      CREATE POLICY "Permitir leitura de notas-sap-anexos"
      ON storage.objects FOR SELECT
      TO public
      USING (bucket_id = 'notas-sap-anexos');
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir upload de notas-sap-anexos'
    ) THEN
      CREATE POLICY "Permitir upload de notas-sap-anexos"
      ON storage.objects FOR INSERT
      TO public
      WITH CHECK (bucket_id = 'notas-sap-anexos');
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir exclusao de notas-sap-anexos'
    ) THEN
      CREATE POLICY "Permitir exclusao de notas-sap-anexos"
      ON storage.objects FOR DELETE
      TO public
      USING (bucket_id = 'notas-sap-anexos');
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir atualizacao de notas-sap-anexos'
    ) THEN
      CREATE POLICY "Permitir atualizacao de notas-sap-anexos"
      ON storage.objects FOR UPDATE
      TO public
      USING (bucket_id = 'notas-sap-anexos')
      WITH CHECK (bucket_id = 'notas-sap-anexos');
    END IF;
  END IF;
END $$;

-- 3. TABELA DE ANEXOS DA NOTA SAP (ESTRUTURA CONSOLIDADA COMPLETA)
CREATE TABLE IF NOT EXISTS public.notas_sap_anexos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_sap_id UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  nome_arquivo VARCHAR(255) NOT NULL,
  nome_original VARCHAR(255),
  tipo_arquivo VARCHAR(20) NOT NULL CHECK (tipo_arquivo IN ('imagem', 'video', 'pdf', 'documento', 'planilha', 'audio', 'outro')),
  caminho_arquivo TEXT NOT NULL,
  tamanho_bytes INTEGER NOT NULL,
  mime_type VARCHAR(100),
  legenda TEXT,
  bucket VARCHAR(100) NOT NULL DEFAULT 'notas-sap-anexos',
  extensao VARCHAR(20),
  origem VARCHAR(30) NOT NULL DEFAULT 'SAP' CHECK (origem IN ('SAP', 'TASKFLOW', 'USUARIO', 'IMPORTACAO')),
  sap_document_id TEXT,
  sha256 VARCHAR(64),
  metadata JSONB DEFAULT '{}'::jsonb,
  importado_em TIMESTAMPTZ,
  relevante_analise BOOLEAN NOT NULL DEFAULT false,
  anexo_derivado_de_id UUID REFERENCES public.notas_sap_anexos(id) ON DELETE SET NULL,
  usuario_id UUID,
  usuario_nome VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Garantir colunas caso a tabela já existisse em versão anterior
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS nome_original VARCHAR(255);
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS bucket VARCHAR(100) DEFAULT 'notas-sap-anexos';
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS extensao VARCHAR(20);
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS origem VARCHAR(30) DEFAULT 'SAP';
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS sap_document_id TEXT;
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS sha256 VARCHAR(64);
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS importado_em TIMESTAMPTZ;
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS relevante_analise BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS anexo_derivado_de_id UUID REFERENCES public.notas_sap_anexos(id) ON DELETE SET NULL;

-- Índices de notas_sap_anexos
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_nota_id ON public.notas_sap_anexos(nota_sap_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_tipo ON public.notas_sap_anexos(tipo_arquivo);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_relevante ON public.notas_sap_anexos(nota_sap_id, relevante_analise);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_origem ON public.notas_sap_anexos(origem);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_bucket ON public.notas_sap_anexos(bucket);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_derivado_de ON public.notas_sap_anexos(anexo_derivado_de_id) WHERE anexo_derivado_de_id IS NOT NULL;

-- Índices de unicidade (idempotência de upload)
CREATE UNIQUE INDEX IF NOT EXISTS uq_notas_sap_anexos_sap_doc ON public.notas_sap_anexos(nota_sap_id, sap_document_id) WHERE sap_document_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_notas_sap_anexos_sha256 ON public.notas_sap_anexos(nota_sap_id, sha256) WHERE sha256 IS NOT NULL;

COMMENT ON TABLE public.notas_sap_anexos IS 'Imagens do defeito, esquemas e documentos técnicos anexados à Nota SAP';

-- 4. TABELA DE ANOTAÇÕES VETORIAIS (APPEND-ONLY)
CREATE TABLE IF NOT EXISTS public.notas_sap_anexos_anotacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anexo_id UUID NOT NULL REFERENCES public.notas_sap_anexos(id) ON DELETE CASCADE,
  versao INT NOT NULL,
  dados_json JSONB NOT NULL,
  imagem_largura INT,
  imagem_altura INT,
  criado_por UUID NULL,
  criado_por_nome TEXT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_anotacao_anexo_versao UNIQUE (anexo_id, versao)
);

CREATE INDEX IF NOT EXISTS idx_anotacoes_anexo_versao ON public.notas_sap_anexos_anotacoes(anexo_id, versao DESC);

COMMENT ON TABLE public.notas_sap_anexos_anotacoes IS 'Anotações técnicas vetoriais não destrutivas em camadas sobre anexos de Notas';

-- 5. POLÍTICAS DE RLS
ALTER TABLE public.notas_sap_anexos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_anexos_anotacoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anexos de notas visíveis para todos" ON public.notas_sap_anexos;
CREATE POLICY "Anexos de notas visíveis para todos" ON public.notas_sap_anexos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários podem gerenciar anexos de notas" ON public.notas_sap_anexos;
CREATE POLICY "Usuários podem gerenciar anexos de notas" ON public.notas_sap_anexos
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir leitura de anotacoes" ON public.notas_sap_anexos_anotacoes;
CREATE POLICY "Permitir leitura de anotacoes" ON public.notas_sap_anexos_anotacoes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Permitir insercao de anotacoes" ON public.notas_sap_anexos_anotacoes;
CREATE POLICY "Permitir insercao de anotacoes" ON public.notas_sap_anexos_anotacoes
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir exclusao de anotacoes" ON public.notas_sap_anexos_anotacoes;
CREATE POLICY "Permitir exclusao de anotacoes" ON public.notas_sap_anexos_anotacoes
  FOR DELETE USING (true);

-- 6. CONCESSÃO DE PRIVILÉGIOS (GRANTS PARA API SUPABASE)
DO $$
BEGIN
  GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_anexos TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_anexos_anotacoes TO anon, authenticated, service_role;
END $$;

COMMIT;
-- ==============================================================================
-- ETAPA 4: Vínculo Polimórfico de Evidências Técnicas da Análise
-- ARQUIVO: 04_analise_evidencias_polimorficas.sql
-- AMBIENTE: Produção (10.140.50.12)
-- DIRETRIZES: Idempotente (IF NOT EXISTS), sem operações destrutivas.
-- ==============================================================================

\set ON_ERROR_STOP 1

BEGIN;

-- 1. VALIDAÇÃO DE TABELAS REFERENCIADAS
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notas_sap_anexos') THEN
    RAISE EXCEPTION 'PRÉ-REQUISITO FALHOU: A tabela public.notas_sap_anexos não existe!';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notas_sap_anexos_anotacoes') THEN
    RAISE EXCEPTION 'PRÉ-REQUISITO FALHOU: A tabela public.notas_sap_anexos_anotacoes não existe!';
  END IF;
END $$;

-- 2. TABELA PRINCIPAL DE EVIDÊNCIAS TÉCNICAS (CONSOLIDADA)
CREATE TABLE IF NOT EXISTS public.notas_sap_analise_evidencias (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nota_sap_id        UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
    tipo_fonte         VARCHAR(30) NOT NULL DEFAULT 'anexo_nota'
                       CHECK (tipo_fonte IN ('anexo_nota', 'foto_album', 'anexo_nota_historica')),
    anexo_id           UUID NULL REFERENCES public.notas_sap_anexos(id) ON DELETE RESTRICT,
    media_image_id     UUID NULL REFERENCES public.media_images(id) ON DELETE RESTRICT,
    tipo_vinculo       VARCHAR(30) NOT NULL CHECK (tipo_vinculo IN (
                           'diagnostico', 'escopo', 'materiais', 'seguranca', 'desligamento', 'acesso', 'outro'
                       )),
    anotacao_versao    INTEGER NULL,
    observacao         TEXT NULL,
    ordem              INTEGER NOT NULL DEFAULT 0,
    criado_por         UUID NULL,
    criado_por_nome    VARCHAR(255) NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Garantir colunas e constraints caso tabela já existisse
ALTER TABLE public.notas_sap_analise_evidencias ADD COLUMN IF NOT EXISTS tipo_fonte VARCHAR(30) NOT NULL DEFAULT 'anexo_nota';
ALTER TABLE public.notas_sap_analise_evidencias ALTER COLUMN anexo_id DROP NOT NULL;
ALTER TABLE public.notas_sap_analise_evidencias ADD COLUMN IF NOT EXISTS media_image_id UUID NULL REFERENCES public.media_images(id) ON DELETE RESTRICT;

-- FK Composta para versão da anotação
ALTER TABLE public.notas_sap_analise_evidencias DROP CONSTRAINT IF EXISTS fk_evidencia_anotacao_versao;
ALTER TABLE public.notas_sap_analise_evidencias 
    ADD CONSTRAINT fk_evidencia_anotacao_versao 
    FOREIGN KEY (anexo_id, anotacao_versao) 
    REFERENCES public.notas_sap_anexos_anotacoes(anexo_id, versao) 
    ON DELETE RESTRICT;

-- Integridade estrita das 3 fontes mutuamente exclusivas
ALTER TABLE public.notas_sap_analise_evidencias DROP CONSTRAINT IF EXISTS chk_evidencia_fonte_integridade;
ALTER TABLE public.notas_sap_analise_evidencias 
    ADD CONSTRAINT chk_evidencia_fonte_integridade CHECK (
        (
            tipo_fonte = 'anexo_nota' 
            AND anexo_id IS NOT NULL 
            AND media_image_id IS NULL
        )
        OR
        (
            tipo_fonte = 'foto_album' 
            AND media_image_id IS NOT NULL 
            AND anexo_id IS NULL 
            AND anotacao_versao IS NULL
        )
        OR
        (
            tipo_fonte = 'anexo_nota_historica' 
            AND anexo_id IS NOT NULL 
            AND media_image_id IS NULL
        )
    );

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_analise_evidencias_nota_id ON public.notas_sap_analise_evidencias(nota_sap_id);
CREATE INDEX IF NOT EXISTS idx_analise_evidencias_anexo_id ON public.notas_sap_analise_evidencias(anexo_id);
CREATE INDEX IF NOT EXISTS idx_analise_evidencias_media_image ON public.notas_sap_analise_evidencias(media_image_id);
CREATE INDEX IF NOT EXISTS idx_analise_evidencias_tipo ON public.notas_sap_analise_evidencias(nota_sap_id, tipo_vinculo);

-- Índices parciais de unicidade por fonte
ALTER TABLE public.notas_sap_analise_evidencias DROP CONSTRAINT IF EXISTS uq_nota_anexo_tipo;

CREATE UNIQUE INDEX IF NOT EXISTS uq_evidencia_anexo_secao
    ON public.notas_sap_analise_evidencias (nota_sap_id, anexo_id, tipo_vinculo)
    WHERE tipo_fonte = 'anexo_nota';

CREATE UNIQUE INDEX IF NOT EXISTS uq_evidencia_album_secao
    ON public.notas_sap_analise_evidencias (nota_sap_id, media_image_id, tipo_vinculo)
    WHERE tipo_fonte = 'foto_album';

CREATE UNIQUE INDEX IF NOT EXISTS uq_evidencia_anexo_historico_secao
    ON public.notas_sap_analise_evidencias (nota_sap_id, anexo_id, tipo_vinculo)
    WHERE tipo_fonte = 'anexo_nota_historica';

COMMENT ON TABLE public.notas_sap_analise_evidencias IS 'Relacionamento polimórfico estruturado N:M entre evidências técnicas e seções da análise';

-- 3. HABILITAR ROW LEVEL SECURITY (RLS)
ALTER TABLE public.notas_sap_analise_evidencias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vínculos de evidências são visíveis para todos" ON public.notas_sap_analise_evidencias;
CREATE POLICY "Vínculos de evidências são visíveis para todos" ON public.notas_sap_analise_evidencias
    FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Usuários podem inserir vínculos de evidências" ON public.notas_sap_analise_evidencias;
CREATE POLICY "Usuários podem inserir vínculos de evidências" ON public.notas_sap_analise_evidencias
    FOR INSERT TO public WITH CHECK (true);

DROP POLICY IF EXISTS "Usuários podem atualizar vínculos de evidências" ON public.notas_sap_analise_evidencias;
CREATE POLICY "Usuários podem atualizar vínculos de evidências" ON public.notas_sap_analise_evidencias
    FOR UPDATE TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Usuários podem excluir vínculos de evidências" ON public.notas_sap_analise_evidencias;
CREATE POLICY "Usuários podem excluir vínculos de evidências" ON public.notas_sap_analise_evidencias
    FOR DELETE TO public USING (true);

-- 4. CONCESSÃO DE PRIVILÉGIOS (GRANTS PARA API SUPABASE)
DO $$
BEGIN
  GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_analise_evidencias TO anon, authenticated, service_role;
END $$;

COMMIT;
-- ==============================================================================
-- ETAPA 5: Catálogo Hierárquico de Tags e Vínculos N:M com Notas SAP
-- ARQUIVO: 05_tags_hierarquicas.sql
-- AMBIENTE: Produção (10.140.50.12)
-- DIRETRIZES: Idempotente (IF NOT EXISTS), sem operações destrutivas.
-- ==============================================================================

\set ON_ERROR_STOP 1

BEGIN;

-- 1. VALIDAÇÃO DE TABELAS HIERÁRQUICAS E NOTAS
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notas_sap') THEN
    RAISE EXCEPTION 'PRÉ-REQUISITO FALHOU: A tabela public.notas_sap não existe!';
  END IF;
END $$;

-- 2. TABELA DO CATÁLOGO DE TAGS HIERÁRQUICAS
CREATE TABLE IF NOT EXISTS public.notas_sap_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome VARCHAR(100) NOT NULL,
  nome_normalizado VARCHAR(100) NOT NULL,
  descricao TEXT,
  categoria VARCHAR(50) DEFAULT 'GERAL',
  cor VARCHAR(9) DEFAULT '#1E88E5',
  icone VARCHAR(50) DEFAULT 'label_outline',
  
  -- Nível hierárquico estrito
  escopo_tipo VARCHAR(20) NOT NULL DEFAULT 'GLOBAL'
    CHECK (escopo_tipo IN ('GLOBAL', 'REGIONAL', 'DIVISAO', 'SEGMENTO')),
    
  -- Chaves estrangeiras opcionais conforme o nível
  regional_id UUID REFERENCES public.regionais(id) ON DELETE CASCADE,
  divisao_id UUID REFERENCES public.divisoes(id) ON DELETE CASCADE,
  segmento_id UUID REFERENCES public.segmentos(id) ON DELETE CASCADE,
  
  ativo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,

  -- Constraint estrita: nenhum escopo híbrido permitido
  CONSTRAINT chk_notas_sap_tags_escopo_consistente CHECK (
    (escopo_tipo = 'GLOBAL'   AND regional_id IS NULL AND divisao_id IS NULL AND segmento_id IS NULL) OR
    (escopo_tipo = 'REGIONAL' AND regional_id IS NOT NULL AND divisao_id IS NULL AND segmento_id IS NULL) OR
    (escopo_tipo = 'DIVISAO'  AND regional_id IS NULL AND divisao_id IS NOT NULL AND segmento_id IS NULL) OR
    (escopo_tipo = 'SEGMENTO' AND regional_id IS NULL AND divisao_id IS NULL AND segmento_id IS NOT NULL)
  )
);

-- Trigger de normalização de nome e atualização de updated_at
CREATE OR REPLACE FUNCTION public.trg_fn_notas_sap_tags_normalizar()
RETURNS TRIGGER AS $$
BEGIN
  NEW.nome = TRIM(NEW.nome);
  NEW.nome_normalizado = LOWER(NEW.nome);
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notas_sap_tags_normalizar ON public.notas_sap_tags;
CREATE TRIGGER trg_notas_sap_tags_normalizar
  BEFORE INSERT OR UPDATE ON public.notas_sap_tags
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_notas_sap_tags_normalizar();

-- Índice único composto tratando NULLs via COALESCE
CREATE UNIQUE INDEX IF NOT EXISTS uq_notas_sap_tags_escopo_nome ON public.notas_sap_tags (
  nome_normalizado,
  escopo_tipo,
  COALESCE(regional_id, '00000000-0000-0000-0000-000000000000'::uuid),
  COALESCE(divisao_id, '00000000-0000-0000-0000-000000000000'::uuid),
  COALESCE(segmento_id, '00000000-0000-0000-0000-000000000000'::uuid)
);

-- Índices de consulta do catálogo
CREATE INDEX IF NOT EXISTS idx_notas_sap_tags_ativo ON public.notas_sap_tags(ativo);
CREATE INDEX IF NOT EXISTS idx_notas_sap_tags_escopo ON public.notas_sap_tags(escopo_tipo);
CREATE INDEX IF NOT EXISTS idx_notas_sap_tags_regional ON public.notas_sap_tags(regional_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_tags_divisao ON public.notas_sap_tags(divisao_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_tags_segmento ON public.notas_sap_tags(segmento_id);

COMMENT ON TABLE public.notas_sap_tags IS 'Catálogo hierárquico de tags para classificação de Notas SAP';

-- 3. TABELA DE VÍNCULOS N:M (NOTA SAP <-> TAG)
CREATE TABLE IF NOT EXISTS public.notas_sap_tags_vinculos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_sap_id UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES public.notas_sap_tags(id) ON DELETE RESTRICT,
  origem VARCHAR(20) NOT NULL DEFAULT 'MANUAL'
    CHECK (origem IN ('MANUAL', 'REGRA', 'SUGESTAO', 'IA')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,

  CONSTRAINT uq_nota_sap_tag UNIQUE (nota_sap_id, tag_id)
);

-- Índices da tabela de vínculos
CREATE INDEX IF NOT EXISTS idx_notas_sap_tags_vinculos_nota ON public.notas_sap_tags_vinculos(nota_sap_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_tags_vinculos_tag ON public.notas_sap_tags_vinculos(tag_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_tags_vinculos_origem ON public.notas_sap_tags_vinculos(origem);

COMMENT ON TABLE public.notas_sap_tags_vinculos IS 'Associações N:M entre Notas SAP e Tags com rastreabilidade';

-- 4. POLÍTICAS RLS
ALTER TABLE public.notas_sap_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_tags_vinculos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tags visíveis para todos" ON public.notas_sap_tags;
CREATE POLICY "Tags visíveis para todos" ON public.notas_sap_tags
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Gerenciamento de tags" ON public.notas_sap_tags;
CREATE POLICY "Gerenciamento de tags" ON public.notas_sap_tags
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Vínculos de tags visíveis para todos" ON public.notas_sap_tags_vinculos;
CREATE POLICY "Vínculos de tags visíveis para todos" ON public.notas_sap_tags_vinculos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Gerenciamento de vínculos de tags" ON public.notas_sap_tags_vinculos;
CREATE POLICY "Gerenciamento de vínculos de tags" ON public.notas_sap_tags_vinculos
  FOR ALL USING (true) WITH CHECK (true);

-- 5. CONCESSÃO DE PRIVILÉGIOS (GRANTS PARA API SUPABASE)
DO $$
BEGIN
  GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_tags TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_tags_vinculos TO anon, authenticated, service_role;
END $$;

COMMIT;
-- ==============================================================================
-- ETAPA 6: Recarregamento de Cache de Schema do PostgREST
-- ARQUIVO: 06_recarregar_schema_postgrest.sql
-- AMBIENTE: Produção (10.140.50.12)
-- ==============================================================================

NOTIFY pgrst, 'reload schema';
