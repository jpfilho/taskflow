-- ============================================
-- MIGRAÇÃO: Anotações de imagens (media_annotations)
-- ============================================
-- Armazena anotações em JSON; imagem original NÃO é alterada.
-- Export PNG opcional em storage; path em media_images.annotated_file_path.
--
-- IMPORTANTE (app com auth interna): após rodar este arquivo, execute
-- CORRIGIR_POLITICAS_MEDIA_ANNOTATIONS.sql para RLS compatível com usuarios.
-- ============================================

-- 1. Tabela media_annotations
CREATE TABLE IF NOT EXISTS public.media_annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_image_id UUID NOT NULL REFERENCES public.media_images(id) ON DELETE CASCADE,
    version INT NOT NULL DEFAULT 1,
    annotations_json JSONB NOT NULL DEFAULT '[]',
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT media_annotations_media_image_id_unique UNIQUE (media_image_id)
);

COMMENT ON TABLE public.media_annotations IS 'Anotações vetoriais (strokes, arrows, polygons, text) em JSON; uma linha por imagem.';
COMMENT ON COLUMN public.media_annotations.annotations_json IS 'Array de objetos: { type, points/pointsList, color, strokeWidth, ... }. Schema em annotation_models.dart.';

-- 2. Colunas opcionais em media_images para export PNG
ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS annotated_file_path TEXT NULL;

ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS annotated_updated_at TIMESTAMPTZ NULL;

COMMENT ON COLUMN public.media_images.annotated_file_path IS 'Path no bucket taskflow-media da imagem exportada com anotações (PNG).';
COMMENT ON COLUMN public.media_images.annotated_updated_at IS 'Data da última exportação de anotações.';

-- 3. Índices
CREATE INDEX IF NOT EXISTS idx_media_annotations_media_image_id ON public.media_annotations(media_image_id);
CREATE INDEX IF NOT EXISTS idx_media_annotations_created_by ON public.media_annotations(created_by);
CREATE INDEX IF NOT EXISTS idx_media_annotations_updated_at ON public.media_annotations(updated_at DESC);

-- 4. Trigger updated_at
CREATE OR REPLACE FUNCTION public.set_media_annotations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_media_annotations_updated_at ON public.media_annotations;
CREATE TRIGGER trigger_media_annotations_updated_at
    BEFORE UPDATE ON public.media_annotations
    FOR EACH ROW
    EXECUTE FUNCTION public.set_media_annotations_updated_at();

-- 5. RLS
ALTER TABLE public.media_annotations ENABLE ROW LEVEL SECURITY;

-- Leitura: usuários autenticados podem ler
DROP POLICY IF EXISTS "media_annotations_select_authenticated" ON public.media_annotations;
CREATE POLICY "media_annotations_select_authenticated"
    ON public.media_annotations FOR SELECT
    TO authenticated
    USING (true);

-- Inserção/atualização/exclusão: apenas o criador
DROP POLICY IF EXISTS "media_annotations_insert_own" ON public.media_annotations;
CREATE POLICY "media_annotations_insert_own"
    ON public.media_annotations FOR INSERT
    TO authenticated
    WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS "media_annotations_update_own" ON public.media_annotations;
CREATE POLICY "media_annotations_update_own"
    ON public.media_annotations FOR UPDATE
    TO authenticated
    USING (created_by = auth.uid())
    WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS "media_annotations_delete_own" ON public.media_annotations;
CREATE POLICY "media_annotations_delete_own"
    ON public.media_annotations FOR DELETE
    TO authenticated
    USING (created_by = auth.uid());
