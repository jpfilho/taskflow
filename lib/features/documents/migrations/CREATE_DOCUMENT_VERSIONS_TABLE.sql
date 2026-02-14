-- ============================================
-- Tabela: document_versions
-- ============================================
-- Histórico de versões dos documentos.
-- Cada upload que substitui arquivo pode gerar nova versão.
-- ============================================

CREATE TABLE IF NOT EXISTS public.document_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    version INT NOT NULL DEFAULT 1,

    file_path TEXT NOT NULL,
    file_url  TEXT,
    mime_type TEXT NOT NULL,
    file_size BIGINT,
    checksum  TEXT,

    created_by UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Constraint de versão única por documento (idempotente)
ALTER TABLE public.document_versions
    DROP CONSTRAINT IF EXISTS document_versions_unique_version;

ALTER TABLE public.document_versions
    ADD CONSTRAINT document_versions_unique_version UNIQUE (document_id, version);

-- Índices
CREATE INDEX IF NOT EXISTS idx_document_versions_document_id ON public.document_versions(document_id);
CREATE INDEX IF NOT EXISTS idx_document_versions_created_at ON public.document_versions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_document_versions_created_by ON public.document_versions(created_by);

-- Comentários
COMMENT ON TABLE public.document_versions IS 'Histórico de versões de documentos.';
COMMENT ON COLUMN public.document_versions.file_path IS 'Path da versão no bucket taskflow-documents.';
