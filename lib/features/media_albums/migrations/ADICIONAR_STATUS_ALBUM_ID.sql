-- ============================================
-- MIGRAÇÃO: Adicionar status_album_id à tabela media_images
-- ============================================
-- Esta migration adiciona a coluna status_album_id para vincular
-- as imagens aos status cadastrados na tabela status_albums
-- ============================================

-- 1. Adicionar coluna status_album_id (nullable para permitir migração gradual)
ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS status_album_id UUID REFERENCES public.status_albums(id) ON DELETE SET NULL;

-- 2. Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_media_images_status_album_id 
ON public.media_images(status_album_id);

-- 3. Migrar dados existentes (opcional - criar status padrão se não existirem)
-- Primeiro, criar status padrão se não existirem
INSERT INTO public.status_albums (nome, descricao, cor_fundo, cor_texto, ativo, ordem)
SELECT 'OK', 'Status aprovado', '#10B981', '#FFFFFF', true, 1
WHERE NOT EXISTS (SELECT 1 FROM public.status_albums WHERE nome = 'OK');

INSERT INTO public.status_albums (nome, descricao, cor_fundo, cor_texto, ativo, ordem)
SELECT 'Atenção', 'Status que requer atenção', '#EF4444', '#FFFFFF', true, 2
WHERE NOT EXISTS (SELECT 1 FROM public.status_albums WHERE nome = 'Atenção');

INSERT INTO public.status_albums (nome, descricao, cor_fundo, cor_texto, ativo, ordem)
SELECT 'Revisão', 'Status em revisão', '#F59E0B', '#FFFFFF', true, 3
WHERE NOT EXISTS (SELECT 1 FROM public.status_albums WHERE nome = 'Revisão');

-- 4. Migrar dados existentes: vincular status TEXT ao status_album_id
UPDATE public.media_images mi
SET status_album_id = (
    SELECT id FROM public.status_albums sa
    WHERE 
        (mi.status = 'ok' AND sa.nome = 'OK')
        OR (mi.status = 'attention' AND sa.nome = 'Atenção')
        OR (mi.status = 'review' AND sa.nome = 'Revisão')
    LIMIT 1
)
WHERE mi.status_album_id IS NULL;

-- 5. Comentários
COMMENT ON COLUMN public.media_images.status_album_id IS 'Referência ao status cadastrado na tabela status_albums';
