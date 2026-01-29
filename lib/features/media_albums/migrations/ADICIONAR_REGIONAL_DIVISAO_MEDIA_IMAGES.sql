-- ============================================
-- MIGRAÇÃO: Regional e Divisão em media_images
-- ============================================
-- Segue o padrão de perfil do usuário: regional → divisão → segmento.
-- Cada usuário só vê/edita/cadastra conforme seu perfil (usuarios_regionais,
-- usuarios_divisoes, usuarios_segmentos). O filtro por perfil é aplicado no app.
-- ============================================

-- 1. Adicionar colunas regional_id e divisao_id (nullable para migração gradual)
ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS regional_id UUID REFERENCES public.regionais(id) ON DELETE SET NULL;

ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS divisao_id UUID REFERENCES public.divisoes(id) ON DELETE SET NULL;

-- 2. Índices para filtros por perfil
CREATE INDEX IF NOT EXISTS idx_media_images_regional_id ON public.media_images(regional_id);
CREATE INDEX IF NOT EXISTS idx_media_images_divisao_id ON public.media_images(divisao_id);

-- 3. Comentários
COMMENT ON COLUMN public.media_images.regional_id IS 'Regional (perfil usuário): só ver/editar/cadastrar dentro do perfil';
COMMENT ON COLUMN public.media_images.divisao_id IS 'Divisão (perfil usuário): só ver/editar/cadastrar dentro do perfil';

-- 4. (Opcional) Preencher regional_id e divisao_id a partir de segmento existente
--    via divisoes_segmentos: um segmento pode estar em várias divisões; pegamos uma.
UPDATE public.media_images mi
SET
  divisao_id = (
    SELECT ds.divisao_id
    FROM public.divisoes_segmentos ds
    WHERE ds.segmento_id = mi.segment_id
    LIMIT 1
  ),
  regional_id = (
    SELECT d.regional_id
    FROM public.divisoes d
    INNER JOIN public.divisoes_segmentos ds ON ds.divisao_id = d.id AND ds.segmento_id = mi.segment_id
    LIMIT 1
  )
WHERE mi.segment_id IS NOT NULL
  AND (mi.regional_id IS NULL OR mi.divisao_id IS NULL);
