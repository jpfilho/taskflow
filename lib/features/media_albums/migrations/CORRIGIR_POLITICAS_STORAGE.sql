-- ============================================
-- CORRIGIR POLÍTICAS DE STORAGE (BUCKET PÚBLICO)
-- ============================================
-- Execute este script se as políticas já existem mas não estão funcionando
-- Este script remove e recria as políticas com as definições corretas
-- 
-- IMPORTANTE: Este bucket é PÚBLICO (como os demais buckets do sistema)
-- As políticas são simplificadas para permitir acesso público ao bucket
-- ============================================

-- IMPORTANTE: Certifique-se de que o bucket 'taskflow-media' existe e está PÚBLICO!
-- Se não existe, crie primeiro no Supabase Dashboard:
-- Storage > Buckets > New Bucket > Name: taskflow-media > Public bucket: ✅ MARCADO

-- ============================================
-- REMOVER POLÍTICAS ANTIGAS
-- ============================================
DROP POLICY IF EXISTS "taskflow_media_select_authenticated" ON storage.objects;
DROP POLICY IF EXISTS "taskflow_media_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "taskflow_media_update_own" ON storage.objects;
DROP POLICY IF EXISTS "taskflow_media_delete_own" ON storage.objects;

-- ============================================
-- RECRIAR POLÍTICAS SIMPLIFICADAS (BUCKET PÚBLICO)
-- ============================================
-- NOTA: Como o bucket é PÚBLICO, as políticas são simplificadas
-- Apenas verificam se o bucket é 'taskflow-media'
-- Isso é consistente com os outros buckets públicos do sistema (anexos-tarefas, sap_exports, etc.)

-- Política 1: SELECT (Leitura)
-- Permite leitura pública de todos os arquivos do bucket
CREATE POLICY "taskflow_media_select_public"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'taskflow-media');

-- Política 2: INSERT (Upload)
-- Permite upload público de arquivos no bucket
CREATE POLICY "taskflow_media_insert_public"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'taskflow-media');

-- Política 3: UPDATE (Atualização)
-- Permite atualização pública de arquivos no bucket
CREATE POLICY "taskflow_media_update_public"
ON storage.objects
FOR UPDATE
TO public
USING (bucket_id = 'taskflow-media')
WITH CHECK (bucket_id = 'taskflow-media');

-- Política 4: DELETE (Exclusão)
-- Permite exclusão pública de arquivos no bucket
CREATE POLICY "taskflow_media_delete_public"
ON storage.objects
FOR DELETE
TO public
USING (bucket_id = 'taskflow-media');

-- ============================================
-- VERIFICAR POLÍTICAS CRIADAS
-- ============================================
-- Execute esta query para verificar se as políticas foram criadas corretamente:
SELECT 
  policyname,
  cmd,
  CASE 
    WHEN qual IS NOT NULL THEN substring(qual::text, 1, 100)
    ELSE 'NULL'
  END as qual_preview,
  CASE 
    WHEN with_check IS NOT NULL THEN substring(with_check::text, 1, 100)
    ELSE 'NULL'
  END as with_check_preview
FROM pg_policies 
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE 'taskflow_media%'
ORDER BY 
  CASE cmd
    WHEN 'SELECT' THEN 1
    WHEN 'INSERT' THEN 2
    WHEN 'UPDATE' THEN 3
    WHEN 'DELETE' THEN 4
  END;

-- ============================================
-- TESTAR POLÍTICAS
-- ============================================
-- Para testar se um path está correto (exemplo):
-- SELECT (string_to_array('b700d4a5-cbf3-492e-8e69-dc48520d858f/43d9ea1b-4c1c-42d8-97f3-d49400844f16/2026/01/test.jpg', '/'))[1];
-- Deve retornar: b700d4a5-cbf3-492e-8e69-dc48520d858f (o userId)
--
-- Para verificar se o userId do path existe na tabela usuarios:
-- SELECT EXISTS (
--   SELECT 1 FROM usuarios 
--   WHERE id::text = (string_to_array('b700d4a5-cbf3-492e-8e69-dc48520d858f/43d9ea1b-4c1c-42d8-97f3-d49400844f16/2026/01/test.jpg', '/'))[1]
-- );
-- Deve retornar TRUE se o userId existe na tabela usuarios
--
-- Para listar todos os usuários (para verificar IDs válidos):
-- SELECT id, email, nome FROM usuarios LIMIT 10;

-- ============================================
-- TROUBLESHOOTING
-- ============================================
-- Se ainda receber erro "new row violates row-level security policy":
--
-- 1. Verifique se o bucket existe e está PÚBLICO:
--    SELECT * FROM storage.buckets WHERE id = 'taskflow-media';
--    O campo 'public' deve ser TRUE
--
-- 2. Se o bucket não estiver público, torne-o público:
--    No Supabase Dashboard: Storage > Buckets > taskflow-media > Edit
--    Marque "Public bucket" e salve
--
-- 3. Verifique se as políticas foram criadas:
--    SELECT policyname, cmd FROM pg_policies 
--    WHERE schemaname = 'storage' AND tablename = 'objects' 
--    AND policyname LIKE 'taskflow_media%';
--
-- 4. Verifique se RLS está habilitado:
--    SELECT tablename, rowsecurity FROM pg_tables 
--    WHERE schemaname = 'storage' AND tablename = 'objects';
--    Deve retornar rowsecurity = true
--
-- 5. Se ainda não funcionar, tente criar as políticas manualmente via Dashboard:
--    Storage > Policies > taskflow-media > New Policy
--    Use as definições acima (apenas bucket_id = 'taskflow-media')
