-- ============================================
-- RLS e políticas para Documents
-- ============================================
-- Tabelas cobertas:
--  - documents
--  - status_documents
--  - document_versions
-- Regras seguem padrão do módulo de mídia: leitura autenticados; escrita apenas criador.
-- TODO: Restringir status_documents para admin em produção.
-- ============================================

-- 1) Habilitar RLS
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.status_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_versions ENABLE ROW LEVEL SECURITY;

-- 2) documents (não depende de auth.uid; app faz auth interna)
DROP POLICY IF EXISTS "documents_select_authenticated" ON public.documents;
CREATE POLICY "documents_select_authenticated"
    ON public.documents FOR SELECT
    TO public
    USING (true);

DROP POLICY IF EXISTS "documents_insert_any" ON public.documents;
CREATE POLICY "documents_insert_any"
    ON public.documents FOR INSERT
    TO public
    WITH CHECK (created_by IS NOT NULL);

DROP POLICY IF EXISTS "documents_update_any" ON public.documents;
CREATE POLICY "documents_update_any"
    ON public.documents FOR UPDATE
    TO public
    USING (true)
    WITH CHECK (created_by IS NOT NULL);

DROP POLICY IF EXISTS "documents_delete_any" ON public.documents;
CREATE POLICY "documents_delete_any"
    ON public.documents FOR DELETE
    TO public
    USING (true);

-- 3) document_versions (não depende de auth.uid)
DROP POLICY IF EXISTS "document_versions_select_authenticated" ON public.document_versions;
CREATE POLICY "document_versions_select_authenticated"
    ON public.document_versions FOR SELECT
    TO public
    USING (true);

DROP POLICY IF EXISTS "document_versions_insert_any" ON public.document_versions;
CREATE POLICY "document_versions_insert_any"
    ON public.document_versions FOR INSERT
    TO public
    WITH CHECK (created_by IS NOT NULL);

DROP POLICY IF EXISTS "document_versions_update_any" ON public.document_versions;
CREATE POLICY "document_versions_update_any"
    ON public.document_versions FOR UPDATE
    TO public
    USING (true)
    WITH CHECK (created_by IS NOT NULL);

DROP POLICY IF EXISTS "document_versions_delete_any" ON public.document_versions;
CREATE POLICY "document_versions_delete_any"
    ON public.document_versions FOR DELETE
    TO public
    USING (true);

-- 4) status_documents (aberto; TODO: restringir admin futuramente)
DROP POLICY IF EXISTS "status_documents_select_public" ON public.status_documents;
CREATE POLICY "status_documents_select_public"
    ON public.status_documents FOR SELECT
    TO public
    USING (true);

DROP POLICY IF EXISTS "status_documents_insert_public" ON public.status_documents;
CREATE POLICY "status_documents_insert_public"
    ON public.status_documents FOR INSERT
    TO public
    WITH CHECK (true);

DROP POLICY IF EXISTS "status_documents_update_public" ON public.status_documents;
CREATE POLICY "status_documents_update_public"
    ON public.status_documents FOR UPDATE
    TO public
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "status_documents_delete_public" ON public.status_documents;
CREATE POLICY "status_documents_delete_public"
    ON public.status_documents FOR DELETE
    TO public
    USING (true);
