-- ============================================
-- Tabela: status_documents
-- ============================================
-- Status dinâmicos para Documents, alinhado a status_albums.
-- Inclui seed inicial de statuses.
-- ============================================

CREATE TABLE IF NOT EXISTS public.status_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    cor_fundo VARCHAR(7),
    cor_texto VARCHAR(7),
    ativo BOOLEAN NOT NULL DEFAULT true,
    ordem INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.usuarios(id),
    CONSTRAINT status_documents_nome_unique UNIQUE (nome)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_status_documents_ativo ON public.status_documents(ativo);
CREATE INDEX IF NOT EXISTS idx_status_documents_ordem ON public.status_documents(ordem);
CREATE INDEX IF NOT EXISTS idx_status_documents_created_by ON public.status_documents(created_by);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION update_status_documents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_status_documents_updated_at ON public.status_documents;
CREATE TRIGGER trigger_update_status_documents_updated_at
    BEFORE UPDATE ON public.status_documents
    FOR EACH ROW
    EXECUTE FUNCTION update_status_documents_updated_at();

-- Seed inicial (idempotente)
INSERT INTO public.status_documents (nome, descricao, cor_fundo, cor_texto, ativo, ordem)
SELECT * FROM (VALUES
    ('Revisar',  'Aguardando revisão', '#F59E0B', '#FFFFFF', true, 1),
    ('Aprovado', 'Aprovado para uso',   '#10B981', '#FFFFFF', true, 2),
    ('Atenção',  'Requer atenção',      '#EF4444', '#FFFFFF', true, 3),
    ('Obsoleto', 'Versão obsoleta',     '#6B7280', '#FFFFFF', true, 4)
) AS v(nome, descricao, cor_fundo, cor_texto, ativo, ordem)
WHERE NOT EXISTS (
    SELECT 1 FROM public.status_documents s WHERE s.nome = v.nome
);

-- Comentários
COMMENT ON TABLE public.status_documents IS 'Status dinâmicos para documentos.';
COMMENT ON COLUMN public.status_documents.nome IS 'Nome do status (ex.: Revisar, Aprovado).';
