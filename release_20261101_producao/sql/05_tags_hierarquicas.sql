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
