-- ============================================
-- POLÍTICAS DE STORAGE PARA DOCUMENTS
-- ============================================
-- Execute após criar o bucket 'taskflow-documents'
-- (Storage > Buckets > New Bucket)
-- ============================================

-- 1. Criar bucket (idempotente)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'taskflow-documents',
    'taskflow-documents',
    false,  -- privado
    104857600, -- 100 MB por arquivo (ajuste se necessário)
    ARRAY[
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'text/plain',
        'application/zip',
        'image/jpeg',
        'image/png',
        'image/webp'
    ]
) ON CONFLICT (id) DO NOTHING;

-- 2. Políticas de storage (prefixo do próprio usuário)
DO $$
BEGIN
    -- SELECT
    BEGIN
        CREATE POLICY "taskflow_documents_select_authenticated"
            ON storage.objects FOR SELECT
            TO authenticated
            USING (bucket_id = 'taskflow-documents');
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Política select já existe';
    END;

    -- INSERT
    BEGIN
        CREATE POLICY "taskflow_documents_insert_own"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (
                bucket_id = 'taskflow-documents'
                AND (string_to_array(name, '/'))[1] = auth.uid()::text
            );
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Política insert já existe';
    END;

    -- UPDATE
    BEGIN
        CREATE POLICY "taskflow_documents_update_own"
            ON storage.objects FOR UPDATE
            TO authenticated
            USING (
                bucket_id = 'taskflow-documents'
                AND (string_to_array(name, '/'))[1] = auth.uid()::text
            )
            WITH CHECK (
                bucket_id = 'taskflow-documents'
                AND (string_to_array(name, '/'))[1] = auth.uid()::text
            );
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Política update já existe';
    END;

    -- DELETE
    BEGIN
        CREATE POLICY "taskflow_documents_delete_own"
            ON storage.objects FOR DELETE
            TO authenticated
            USING (
                bucket_id = 'taskflow-documents'
                AND (string_to_array(name, '/'))[1] = auth.uid()::text
            );
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Política delete já existe';
    END;
END $$;

-- 3. Notas
-- - Estrutura de path esperada: {userId}/{segmentId}/{equipmentId}/{roomId}/{yyyy}/{mm}/{uuid}.{ext}
-- - Bucket é privado: usar Signed URL para acesso.
-- - Se receber erro de permissão, criar políticas via Dashboard (Storage > Policies).
