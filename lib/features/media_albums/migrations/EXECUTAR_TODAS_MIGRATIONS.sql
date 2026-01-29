-- ============================================
-- MIGRAÇÕES COMPLETAS: Status de Álbuns
-- ============================================
-- Execute este arquivo completo no Supabase SQL Editor
-- ============================================

-- ============================================
-- PARTE 1: Criar tabela status_albums
-- ============================================

CREATE TABLE IF NOT EXISTS public.status_albums (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    cor_fundo VARCHAR(7), -- Cor de fundo em hexadecimal (ex: #FF5733)
    cor_texto VARCHAR(7), -- Cor do texto em hexadecimal (ex: #FFFFFF)
    ativo BOOLEAN NOT NULL DEFAULT true,
    ordem INTEGER DEFAULT 0, -- Ordem de exibição
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.usuarios(id),
    CONSTRAINT status_albums_nome_unique UNIQUE (nome)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_status_albums_ativo ON public.status_albums(ativo);
CREATE INDEX IF NOT EXISTS idx_status_albums_ordem ON public.status_albums(ordem);
CREATE INDEX IF NOT EXISTS idx_status_albums_created_by ON public.status_albums(created_by);

-- Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_status_albums_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remover trigger se já existir antes de criar
DROP TRIGGER IF EXISTS trigger_update_status_albums_updated_at ON public.status_albums;

CREATE TRIGGER trigger_update_status_albums_updated_at
    BEFORE UPDATE ON public.status_albums
    FOR EACH ROW
    EXECUTE FUNCTION update_status_albums_updated_at();

-- Habilitar RLS
ALTER TABLE public.status_albums ENABLE ROW LEVEL SECURITY;

-- Políticas RLS (público, similar ao padrão do sistema)
-- Remover políticas existentes antes de criar (para evitar conflitos)
DROP POLICY IF EXISTS "status_albums_select_public" ON public.status_albums;
DROP POLICY IF EXISTS "status_albums_insert_public" ON public.status_albums;
DROP POLICY IF EXISTS "status_albums_update_public" ON public.status_albums;
DROP POLICY IF EXISTS "status_albums_delete_public" ON public.status_albums;

-- SELECT: Todos os usuários autenticados podem ler
CREATE POLICY "status_albums_select_public"
ON public.status_albums
FOR SELECT
TO public
USING (true);

-- INSERT: Usuários autenticados podem criar
CREATE POLICY "status_albums_insert_public"
ON public.status_albums
FOR INSERT
TO public
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.usuarios
        WHERE id::text = created_by::text
    )
);

-- UPDATE: Usuários autenticados podem atualizar
CREATE POLICY "status_albums_update_public"
ON public.status_albums
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);

-- DELETE: Usuários autenticados podem deletar
CREATE POLICY "status_albums_delete_public"
ON public.status_albums
FOR DELETE
TO public
USING (true);

-- Comentários
COMMENT ON TABLE public.status_albums IS 'Tabela para cadastro de status de álbuns de imagens com cores customizadas';
COMMENT ON COLUMN public.status_albums.nome IS 'Nome do status (ex: OK, Atenção, Revisão)';
COMMENT ON COLUMN public.status_albums.descricao IS 'Descrição opcional do status';
COMMENT ON COLUMN public.status_albums.cor_fundo IS 'Cor de fundo em hexadecimal (ex: #FF5733)';
COMMENT ON COLUMN public.status_albums.cor_texto IS 'Cor do texto em hexadecimal (ex: #FFFFFF)';
COMMENT ON COLUMN public.status_albums.ativo IS 'Indica se o status está ativo';
COMMENT ON COLUMN public.status_albums.ordem IS 'Ordem de exibição do status';

-- ============================================
-- PARTE 2: Adicionar status_album_id em media_images
-- ============================================

-- 1. Adicionar coluna status_album_id (nullable para permitir migração gradual)
ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS status_album_id UUID REFERENCES public.status_albums(id) ON DELETE SET NULL;

-- 2. Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_media_images_status_album_id 
ON public.media_images(status_album_id);

-- 3. Criar status padrão se não existirem
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

-- 5. Comentário
COMMENT ON COLUMN public.media_images.status_album_id IS 'Referência ao status cadastrado na tabela status_albums';

-- ============================================
-- VERIFICAÇÃO FINAL
-- ============================================

-- Verificar status criados
SELECT id, nome, cor_fundo, cor_texto, ativo, ordem
FROM public.status_albums
ORDER BY ordem, nome;

-- Verificar imagens com status vinculado (primeiras 10)
SELECT 
    mi.id,
    mi.title,
    mi.status as status_antigo,
    mi.status_album_id,
    sa.nome as status_nome,
    sa.cor_fundo,
    sa.cor_texto
FROM public.media_images mi
LEFT JOIN public.status_albums sa ON mi.status_album_id = sa.id
ORDER BY mi.created_at DESC
LIMIT 10;

-- ============================================
-- PARTE 3: Regional e Divisão em media_images (perfil usuário)
-- ============================================

ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS regional_id UUID REFERENCES public.regionais(id) ON DELETE SET NULL;

ALTER TABLE public.media_images
ADD COLUMN IF NOT EXISTS divisao_id UUID REFERENCES public.divisoes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_media_images_regional_id ON public.media_images(regional_id);
CREATE INDEX IF NOT EXISTS idx_media_images_divisao_id ON public.media_images(divisao_id);

COMMENT ON COLUMN public.media_images.regional_id IS 'Regional (perfil): usuário só vê/edita/cadastra dentro do perfil';
COMMENT ON COLUMN public.media_images.divisao_id IS 'Divisão (perfil): usuário só vê/edita/cadastra dentro do perfil';

-- Preencher regional_id e divisao_id a partir de segment_id existente
UPDATE public.media_images mi
SET
  divisao_id = (SELECT ds.divisao_id FROM public.divisoes_segmentos ds WHERE ds.segmento_id = mi.segment_id LIMIT 1),
  regional_id = (SELECT d.regional_id FROM public.divisoes d INNER JOIN public.divisoes_segmentos ds ON ds.divisao_id = d.id AND ds.segmento_id = mi.segment_id LIMIT 1)
WHERE mi.segment_id IS NOT NULL AND (mi.regional_id IS NULL OR mi.divisao_id IS NULL);
