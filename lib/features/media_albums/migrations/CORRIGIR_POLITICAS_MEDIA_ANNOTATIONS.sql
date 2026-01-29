-- ============================================
-- CORRIGIR POLÍTICAS RLS DA TABELA media_annotations
-- ============================================
-- Este app NÃO usa autenticação do Supabase (auth.uid()).
-- As políticas devem validar created_by na tabela public.usuarios.
-- Execute este script após CREATE_MEDIA_ANNOTATIONS.sql
-- ============================================

-- 1. Remover FK para auth.users (app usa usuários da tabela usuarios)
ALTER TABLE public.media_annotations
DROP CONSTRAINT IF EXISTS media_annotations_created_by_fkey;

-- 2. Remover políticas antigas (baseadas em authenticated / auth.uid())
DROP POLICY IF EXISTS "media_annotations_select_authenticated" ON public.media_annotations;
DROP POLICY IF EXISTS "media_annotations_insert_own" ON public.media_annotations;
DROP POLICY IF EXISTS "media_annotations_update_own" ON public.media_annotations;
DROP POLICY IF EXISTS "media_annotations_delete_own" ON public.media_annotations;

-- 3. Criar políticas para TO public, validando created_by em usuarios
-- SELECT: permitir leitura se created_by existe em usuarios (ou todas as linhas, para simplicidade)
CREATE POLICY "media_annotations_select_public"
ON public.media_annotations
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id::text = media_annotations.created_by::text
  )
);

-- INSERT: permitir se created_by existe em usuarios
CREATE POLICY "media_annotations_insert_public"
ON public.media_annotations
FOR INSERT
TO public
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id::text = created_by::text
  )
);

-- UPDATE: permitir se created_by existe em usuarios
CREATE POLICY "media_annotations_update_public"
ON public.media_annotations
FOR UPDATE
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id::text = media_annotations.created_by::text
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id::text = created_by::text
  )
);

-- DELETE: permitir se created_by existe em usuarios
CREATE POLICY "media_annotations_delete_public"
ON public.media_annotations
FOR DELETE
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id::text = media_annotations.created_by::text
  )
);
