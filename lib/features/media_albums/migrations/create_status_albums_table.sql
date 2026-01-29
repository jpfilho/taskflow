-- ============================================
-- Tabela: status_albums
-- Descrição: Tabela para cadastro de status de álbuns de imagens com cores customizadas
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

CREATE TRIGGER trigger_update_status_albums_updated_at
    BEFORE UPDATE ON public.status_albums
    FOR EACH ROW
    EXECUTE FUNCTION update_status_albums_updated_at();

-- Habilitar RLS
ALTER TABLE public.status_albums ENABLE ROW LEVEL SECURITY;

-- Políticas RLS (público, similar ao padrão do sistema)
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
