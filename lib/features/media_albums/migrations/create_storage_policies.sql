-- ============================================
-- POLÍTICAS DE STORAGE PARA ÁLBUNS DE MÍDIA
-- ============================================
-- Execute este arquivo APÓS criar o bucket 'taskflow-media'
-- no Supabase Dashboard (Storage > Buckets > New Bucket)
-- ============================================

-- IMPORTANTE: Certifique-se de que o bucket 'taskflow-media' foi criado antes!
-- Se não foi criado, execute no Supabase Dashboard:
-- Storage > Buckets > New Bucket
-- - Name: taskflow-media
-- - Public: false (deixar desmarcado = privado)

-- ============================================
-- 1. CRIAR BUCKET (se ainda não existir)
-- ============================================
-- NOTA: Se o bucket já existe, este comando não fará nada
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'taskflow-media',
    'taskflow-media',
    false,  -- Privado
    52428800,  -- 50MB limite por arquivo
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 2. POLÍTICAS DE STORAGE
-- ============================================
-- NOTA: As políticas de storage devem ser criadas via Supabase Dashboard
-- ou usando a API REST do Supabase, não diretamente via SQL.
-- 
-- ALTERNATIVA 1: Via Supabase Dashboard (RECOMENDADO)
-- 1. Vá em Storage > Policies
-- 2. Selecione o bucket 'taskflow-media'
-- 3. Clique em "New Policy"
-- 4. Use os templates abaixo
--
-- ALTERNATIVA 2: Via SQL (requer permissões de service_role)
-- Execute este bloco apenas se tiver acesso como service_role
-- ============================================

-- IMPORTANTE: Se você receber erro "must be owner of table objects",
-- use o Supabase Dashboard para criar as políticas manualmente!

-- Tentar criar políticas (pode falhar se não tiver permissão)
DO $$
BEGIN
    -- Política 1: SELECT (Leitura)
    -- Permite que usuários autenticados leiam qualquer arquivo do bucket
    BEGIN
        CREATE POLICY "taskflow_media_select_authenticated"
            ON storage.objects FOR SELECT
            TO authenticated
            USING (bucket_id = 'taskflow-media');
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Política taskflow_media_select_authenticated já existe';
    END;

    -- Política 2: INSERT (Upload)
    -- Permite que usuários autenticados façam upload apenas em suas próprias pastas
    BEGIN
        CREATE POLICY "taskflow_media_insert_own"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (
                bucket_id = 'taskflow-media' AND
                (string_to_array(name, '/'))[1] = auth.uid()::text
            );
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Política taskflow_media_insert_own já existe';
    END;

    -- Política 3: UPDATE (Atualização)
    BEGIN
        CREATE POLICY "taskflow_media_update_own"
            ON storage.objects FOR UPDATE
            TO authenticated
            USING (
                bucket_id = 'taskflow-media' AND
                (string_to_array(name, '/'))[1] = auth.uid()::text
            )
            WITH CHECK (
                bucket_id = 'taskflow-media' AND
                (string_to_array(name, '/'))[1] = auth.uid()::text
            );
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Política taskflow_media_update_own já existe';
    END;

    -- Política 4: DELETE (Exclusão)
    BEGIN
        CREATE POLICY "taskflow_media_delete_own"
            ON storage.objects FOR DELETE
            TO authenticated
            USING (
                bucket_id = 'taskflow-media' AND
                (string_to_array(name, '/'))[1] = auth.uid()::text
            );
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Política taskflow_media_delete_own já existe';
    END;
END $$;

-- ============================================
-- VERIFICAÇÃO
-- ============================================
-- Execute estas queries para verificar se tudo está correto:

-- Verificar se o bucket foi criado:
SELECT * FROM storage.buckets WHERE id = 'taskflow-media';

-- Verificar políticas criadas (pode não funcionar se não tiver permissão):
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE 'taskflow_media%';

-- ============================================
-- SE RECEBER ERRO "must be owner of table objects"
-- ============================================
-- Use o Supabase Dashboard para criar as políticas manualmente:
-- 1. Vá em Storage > Policies
-- 2. Selecione o bucket 'taskflow-media'
-- 3. Clique em "New Policy" para cada política
-- 4. Use os templates do arquivo: create_storage_policies_manual.md
-- ============================================

-- ============================================
-- NOTAS IMPORTANTES
-- ============================================
-- 1. O bucket é PRIVADO (public = false), então URLs públicas não funcionarão
-- 2. Use signed URLs para acesso temporário aos arquivos
-- 3. A estrutura de pastas é: {userId}/{segmentId}/{equipmentId}/{roomId}/{year}/{month}/{filename}
-- 4. A primeira pasta DEVE ser o userId do usuário autenticado para as políticas funcionarem
-- 5. Limite de tamanho: 50MB por arquivo (pode ser ajustado)
-- 6. Tipos MIME permitidos: JPEG, PNG, WEBP, GIF

-- ============================================
-- TROUBLESHOOTING
-- ============================================
-- Se você receber erro "bucket does not exist":
-- 1. Vá ao Supabase Dashboard > Storage > Buckets
-- 2. Clique em "New Bucket"
-- 3. Nome: taskflow-media
-- 4. Deixe "Public bucket" DESMARCADO
-- 5. Clique em "Create bucket"
-- 6. Execute este script novamente

-- Se você receber erro de permissão:
-- 1. Verifique se RLS está habilitado: SELECT * FROM pg_tables WHERE tablename = 'objects';
-- 2. Verifique se as políticas foram criadas: SELECT * FROM pg_policies WHERE tablename = 'objects';
-- 3. Verifique se o usuário está autenticado: SELECT auth.uid();
