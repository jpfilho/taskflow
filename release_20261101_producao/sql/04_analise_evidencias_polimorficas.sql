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
