-- ==============================================================================
-- MIGRATION: 20261031_suporte_evidencias_analise_sap.sql
-- DESCRIÇÃO: Tabela de relacionamento N:M entre Evidências Técnicas (Anexos) e Seções da Análise
-- OBJETIVO: Conectar formalmente evidências ao Diagnóstico, Escopo, Materiais,
--           Segurança, Desligamento, Acesso e Evidências complementares.
-- PRINCÍPIOS:
--   1. Contextualizada por nota_sap_id (funciona mesmo sem registro prévio em notas_sap_analises).
--   2. FK anexo_id aponta EXCLUSIVAMENTE para o anexo original.
--   3. FK composta (anexo_id, anotacao_versao) assegura integridade referencial com versões reais.
--   4. anotacao_versao IS NULL suportado nativamente (evidência baseada em arquivo puro/sem anotação).
--   5. Unicidade por (nota_sap_id, anexo_id, tipo_vinculo).
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.notas_sap_analise_evidencias (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    nota_sap_id        UUID NOT NULL
        REFERENCES public.notas_sap(id)
        ON DELETE CASCADE,

    anexo_id           UUID NOT NULL
        REFERENCES public.notas_sap_anexos(id)
        ON DELETE CASCADE,

    tipo_vinculo       VARCHAR(30) NOT NULL,

    anotacao_versao    INTEGER NULL,

    observacao         TEXT NULL,

    ordem              INTEGER NOT NULL DEFAULT 0,

    criado_por         UUID NULL,
    criado_por_nome    VARCHAR(255) NULL,

    created_at         TIMESTAMPTZ NOT NULL
        DEFAULT timezone('utc'::text, now()),

    updated_at         TIMESTAMPTZ NOT NULL
        DEFAULT timezone('utc'::text, now()),

    CONSTRAINT chk_tipo_vinculo CHECK (
        tipo_vinculo IN (
            'diagnostico',
            'escopo',
            'materiais',
            'seguranca',
            'desligamento',
            'acesso',
            'outro'
        )
    ),

    CONSTRAINT uq_nota_anexo_tipo
        UNIQUE (nota_sap_id, anexo_id, tipo_vinculo),

    CONSTRAINT fk_evidencia_anotacao_versao
        FOREIGN KEY (anexo_id, anotacao_versao)
        REFERENCES public.notas_sap_anexos_anotacoes(anexo_id, versao)
        ON DELETE CASCADE
);

-- Índices otimizados para busca rápida em lote por Nota e por Anexo
CREATE INDEX IF NOT EXISTS idx_analise_evidencias_nota_id
    ON public.notas_sap_analise_evidencias(nota_sap_id);

CREATE INDEX IF NOT EXISTS idx_analise_evidencias_anexo_id
    ON public.notas_sap_analise_evidencias(anexo_id);

CREATE INDEX IF NOT EXISTS idx_analise_evidencias_tipo
    ON public.notas_sap_analise_evidencias(nota_sap_id, tipo_vinculo);

-- Comentários descritivos
COMMENT ON TABLE public.notas_sap_analise_evidencias IS 
    'Relacionamento estruturado N:M entre anexos e seções técnicas da análise da Nota SAP';
COMMENT ON COLUMN public.notas_sap_analise_evidencias.anexo_id IS 
    'ID do anexo ORIGINAL que fundamenta a análise técnica';
COMMENT ON COLUMN public.notas_sap_analise_evidencias.anotacao_versao IS 
    'Versão específica da anotação vinculada (NULL = arquivo original sem anotações)';
COMMENT ON COLUMN public.notas_sap_analise_evidencias.observacao IS 
    'Justificativa ou nota contextual específica deste anexo para esta seção';

-- RLS: Habilitar e configurar policies compatíveis com modelo atual do TaskFlow
ALTER TABLE public.notas_sap_analise_evidencias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Vínculos de evidências são visíveis para todos" ON public.notas_sap_analise_evidencias;
CREATE POLICY "Vínculos de evidências são visíveis para todos" ON public.notas_sap_analise_evidencias
    FOR SELECT TO public
    USING (true);

DROP POLICY IF EXISTS "Usuários podem inserir vínculos de evidências" ON public.notas_sap_analise_evidencias;
CREATE POLICY "Usuários podem inserir vínculos de evidências" ON public.notas_sap_analise_evidencias
    FOR INSERT TO public
    WITH CHECK (true);

DROP POLICY IF EXISTS "Usuários podem atualizar vínculos de evidências" ON public.notas_sap_analise_evidencias;
CREATE POLICY "Usuários podem atualizar vínculos de evidências" ON public.notas_sap_analise_evidencias
    FOR UPDATE TO public
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Usuários podem excluir vínculos de evidências" ON public.notas_sap_analise_evidencias;
CREATE POLICY "Usuários podem excluir vínculos de evidências" ON public.notas_sap_analise_evidencias
    FOR DELETE TO public
    USING (true);
