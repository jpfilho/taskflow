-- ============================================
-- Tabela: documents (módulo Documents)
-- ============================================
-- Estrutura alinhada ao módulo media_albums:
-- - Hierarquia: segment -> equipment -> room
-- - Perfil: regional/divisao/local
-- - Metadados e storage: file_path, file_url, thumb_path
-- - Status dinâmico: status_document_id (FK status_documents)
-- - Audit: created_by, created_at, updated_at
-- ============================================

-- 1. Tabela principal
CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Hierarquia (nullable para migração gradual)
    segment_id   UUID REFERENCES public.segments(id)   ON DELETE SET NULL,
    equipment_id UUID REFERENCES public.equipments(id) ON DELETE SET NULL,
    room_id      UUID REFERENCES public.rooms(id)      ON DELETE SET NULL,

    -- Perfil / locais (padrão media_images)
    regional_id UUID REFERENCES public.regionais(id) ON DELETE SET NULL,
    divisao_id  UUID REFERENCES public.divisoes(id)  ON DELETE SET NULL,
    local_id    UUID REFERENCES public.locais(id)    ON DELETE SET NULL,

    -- Metadados
    title       TEXT NOT NULL,
    description TEXT,
    tags        TEXT[] DEFAULT '{}',
    mime_type   TEXT NOT NULL,
    file_size   BIGINT,
    file_ext    TEXT,
    checksum    TEXT, -- sha256 opcional

    -- Storage
    file_path TEXT NOT NULL,
    file_url  TEXT,
    thumb_path TEXT,

    -- Status dinâmico
    status_document_id UUID REFERENCES public.status_documents(id) ON DELETE SET NULL,

    -- Auditoria
    created_by UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Função + trigger updated_at
CREATE OR REPLACE FUNCTION public.update_documents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_documents_updated_at ON public.documents;
CREATE TRIGGER trigger_update_documents_updated_at
    BEFORE UPDATE ON public.documents
    FOR EACH ROW
    EXECUTE FUNCTION public.update_documents_updated_at();

-- 3. Índices para filtros e performance
CREATE INDEX IF NOT EXISTS idx_documents_segment_id   ON public.documents(segment_id);
CREATE INDEX IF NOT EXISTS idx_documents_equipment_id ON public.documents(equipment_id);
CREATE INDEX IF NOT EXISTS idx_documents_room_id      ON public.documents(room_id);
CREATE INDEX IF NOT EXISTS idx_documents_regional_id  ON public.documents(regional_id);
CREATE INDEX IF NOT EXISTS idx_documents_divisao_id   ON public.documents(divisao_id);
CREATE INDEX IF NOT EXISTS idx_documents_local_id     ON public.documents(local_id);
CREATE INDEX IF NOT EXISTS idx_documents_created_at_desc ON public.documents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_created_by      ON public.documents(created_by);
CREATE INDEX IF NOT EXISTS idx_documents_status_document_id ON public.documents(status_document_id);

-- Índice GIN para tags
CREATE INDEX IF NOT EXISTS idx_documents_tags_gin ON public.documents USING GIN(tags);

-- Full-text search em título + descrição
CREATE INDEX IF NOT EXISTS idx_documents_search ON public.documents USING GIN(
    to_tsvector('portuguese', COALESCE(title, '') || ' ' || COALESCE(description, ''))
);

-- Comentários
COMMENT ON TABLE public.documents IS 'Documentos (PDF/DOCX/etc) com hierarquia e status dinâmico.';
COMMENT ON COLUMN public.documents.file_path IS 'Path no bucket taskflow-documents (privado).';
COMMENT ON COLUMN public.documents.file_url  IS 'Signed URL opcional (cache).';
COMMENT ON COLUMN public.documents.status_document_id IS 'Status dinâmico (status_documents).';
COMMENT ON COLUMN public.documents.thumb_path IS 'Thumb opcional (PDF/imagem).';
