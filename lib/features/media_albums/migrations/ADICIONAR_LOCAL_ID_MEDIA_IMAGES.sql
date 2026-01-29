-- ============================================
-- Migração: local_id em media_images
-- ============================================
-- O Local vem da tabela "locais" do sistema. Ao cadastrar/editar uma imagem,
-- o usuário escolhe Regional > Divisão > Segmento > Local > Sala.
-- Esta migração adiciona local_id para persistir o local e exibir o nome
-- (locais.local) na tela de detalhes e nos cards.
-- ============================================

-- 1. Adicionar coluna local_id (nullable; referência à tabela locais do sistema)
ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS local_id UUID REFERENCES public.locais(id) ON DELETE SET NULL;

-- 2. Índice para filtros
CREATE INDEX IF NOT EXISTS idx_media_images_local_id ON public.media_images(local_id);

-- 3. Comentário
COMMENT ON COLUMN public.media_images.local_id IS 'Local de instalação (tabela locais). Usado para exibir "Local" na hierarquia e nos detalhes.';
