-- ============================================
-- CORRIGIR POLÍTICAS RLS DA TABELA media_images
-- ============================================
-- Execute este script se as políticas estão bloqueando inserções
-- Este script remove e recria as políticas sem depender de auth.uid()
-- 
-- IMPORTANTE: Este app NÃO usa autenticação do Supabase (auth.uid()),
-- então as políticas verificam se o created_by existe na tabela usuarios
-- ============================================

-- ============================================
-- REMOVER POLÍTICAS ANTIGAS
-- ============================================
DROP POLICY IF EXISTS "media_images_select_authenticated" ON media_images;
DROP POLICY IF EXISTS "media_images_insert_own" ON media_images;
DROP POLICY IF EXISTS "media_images_update_own" ON media_images;
DROP POLICY IF EXISTS "media_images_delete_own" ON media_images;

-- ============================================
-- RECRIAR POLÍTICAS CORRETAS
-- ============================================
-- NOTA: Como o app não usa auth.uid(), as políticas verificam se:
-- 1. O created_by existe na tabela usuarios (para INSERT/UPDATE/DELETE)
-- 2. Para SELECT, permitir leitura se o created_by existe na tabela usuarios

-- Política 1: SELECT (Leitura)
-- Permite leitura de imagens se o created_by existe na tabela usuarios
-- NOTA: Comparação usando ::text para compatibilidade
CREATE POLICY "media_images_select_public"
ON media_images
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1 FROM usuarios 
    WHERE id::text = created_by::text
  )
);

-- Política 2: INSERT (Inserção)
-- IMPORTANTE: Para INSERT, o WITH CHECK é o que importa!
-- Permite inserção se o created_by existe na tabela usuarios
-- NOTA: Comparação usando ::text para compatibilidade
CREATE POLICY "media_images_insert_public"
ON media_images
FOR INSERT
TO public
WITH CHECK (
  EXISTS (
    SELECT 1 FROM usuarios 
    WHERE id::text = created_by::text
  )
);

-- Política 3: UPDATE (Atualização)
-- Permite atualização se o created_by existe na tabela usuarios
-- NOTA: Comparação usando ::text para compatibilidade
CREATE POLICY "media_images_update_public"
ON media_images
FOR UPDATE
TO public
USING (
  EXISTS (
    SELECT 1 FROM usuarios 
    WHERE id::text = created_by::text
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM usuarios 
    WHERE id::text = created_by::text
  )
);

-- Política 4: DELETE (Exclusão)
-- Permite exclusão se o created_by existe na tabela usuarios
-- NOTA: Comparação usando ::text para compatibilidade
CREATE POLICY "media_images_delete_public"
ON media_images
FOR DELETE
TO public
USING (
  EXISTS (
    SELECT 1 FROM usuarios 
    WHERE id::text = created_by::text
  )
);

-- ============================================
-- VERIFICAR POLÍTICAS CRIADAS
-- ============================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'media_images' 
  AND schemaname = 'public'
ORDER BY policyname;

-- ============================================
-- TESTAR POLÍTICAS
-- ============================================
-- Para testar se um created_by existe na tabela usuarios:
-- SELECT EXISTS (
--   SELECT 1 FROM usuarios 
--   WHERE id::text = 'b700d4a5-cbf3-492e-8e69-dc48520d858f'
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
-- 1. Verifique se RLS está habilitado:
--    SELECT tablename, rowsecurity FROM pg_tables 
--    WHERE schemaname = 'public' AND tablename = 'media_images';
--    Deve retornar rowsecurity = true
--
-- 2. Verifique se o created_by existe na tabela usuarios:
--    SELECT id, email FROM usuarios WHERE id::text = 'b700d4a5-cbf3-492e-8e69-dc48520d858f';
--    (Substitua pelo userId do seu created_by)
--
-- 3. Verifique se as políticas foram criadas:
--    SELECT policyname, cmd FROM pg_policies 
--    WHERE schemaname = 'public' AND tablename = 'media_images';
--
-- 4. Verifique o tipo da coluna created_by:
--    SELECT column_name, data_type FROM information_schema.columns 
--    WHERE table_schema = 'public' AND table_name = 'media_images' AND column_name = 'created_by';
--    Deve ser UUID
--
-- 5. Se ainda não funcionar, tente criar as políticas manualmente via Dashboard:
--    Database > Tables > media_images > Policies > New Policy
--    Use as definições acima (sem auth.uid(), usando EXISTS com tabela usuarios)
