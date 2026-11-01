-- ==============================================================================
-- MIGRATION: 20261031_suporte_evidencias_albuns.sql
-- DESCRIÇÃO: Expande notas_sap_analise_evidencias para suportar polimorfismo entre:
--           1. Anexos da Nota (notas_sap_anexos)
--           2. Fotos históricas do Álbum (media_images)
-- PRINCÍPIOS ARQUITETURAIS:
--   - Não duplicar imagens no Storage (media_images permanece no bucket taskflow-media).
--   - Integridade estrita: CHECK constraint assegura exclusividade mútua de IDs e proíbe versão em fotos de álbum.
--   - Proteção de exclusão: media_image_id ON DELETE RESTRICT impede que fotos em uso em análises sejam deletadas.
--   - Rastreabilidade histórica: anotações versionadas com ON DELETE RESTRICT.
--   - Unicidade polimórfica via índices parciais (evita falso positivo com NULLs no Postgres).
-- ==============================================================================

-- 1. Adicionar tipo_fonte
ALTER TABLE public.notas_sap_analise_evidencias 
    ADD COLUMN IF NOT EXISTS tipo_fonte VARCHAR(20) NOT NULL DEFAULT 'anexo_nota';

-- 2. Permitir que anexo_id seja NULL (quando a fonte for foto_album)
ALTER TABLE public.notas_sap_analise_evidencias 
    ALTER COLUMN anexo_id DROP NOT NULL;

-- 3. Adicionar media_image_id referenciando media_images com ON DELETE RESTRICT
ALTER TABLE public.notas_sap_analise_evidencias 
    ADD COLUMN IF NOT EXISTS media_image_id UUID NULL 
    REFERENCES public.media_images(id) 
    ON DELETE RESTRICT;

-- 4. Atualizar FK de anotação para ON DELETE RESTRICT (preservar rastreabilidade histórica)
ALTER TABLE public.notas_sap_analise_evidencias 
    DROP CONSTRAINT IF EXISTS fk_evidencia_anotacao_versao;

ALTER TABLE public.notas_sap_analise_evidencias 
    ADD CONSTRAINT fk_evidencia_anotacao_versao 
    FOREIGN KEY (anexo_id, anotacao_versao) 
    REFERENCES public.notas_sap_anexos_anotacoes(anexo_id, versao) 
    ON DELETE RESTRICT;

-- 5. Adicionar CHECK constraint de integridade de fonte
ALTER TABLE public.notas_sap_analise_evidencias 
    DROP CONSTRAINT IF EXISTS chk_evidencia_fonte_integridade;

ALTER TABLE public.notas_sap_analise_evidencias 
    ADD CONSTRAINT chk_evidencia_fonte_integridade CHECK (
        (
            tipo_fonte = 'anexo_nota' 
            AND anexo_id IS NOT NULL 
            AND media_image_id IS NULL
        )
        OR
        (
            tipo_fonte = 'foto_album' 
            AND media_image_id IS NOT NULL 
            AND anexo_id IS NULL 
            AND anotacao_versao IS NULL
        )
    );

-- 6. Substituir constraint única antiga por índices únicos parciais
ALTER TABLE public.notas_sap_analise_evidencias 
    DROP CONSTRAINT IF EXISTS uq_nota_anexo_tipo;

CREATE UNIQUE INDEX IF NOT EXISTS uq_evidencia_anexo_secao
    ON public.notas_sap_analise_evidencias (nota_sap_id, anexo_id, tipo_vinculo)
    WHERE tipo_fonte = 'anexo_nota';

CREATE UNIQUE INDEX IF NOT EXISTS uq_evidencia_album_secao
    ON public.notas_sap_analise_evidencias (nota_sap_id, media_image_id, tipo_vinculo)
    WHERE tipo_fonte = 'foto_album';

-- 7. Índice otimizado para consultas por media_image_id
CREATE INDEX IF NOT EXISTS idx_analise_evidencias_media_image_id
    ON public.notas_sap_analise_evidencias(media_image_id);

-- Comentários descritivos
COMMENT ON COLUMN public.notas_sap_analise_evidencias.tipo_fonte IS 
    'Fonte da evidência: anexo_nota (notas_sap_anexos) ou foto_album (media_images)';
COMMENT ON COLUMN public.notas_sap_analise_evidencias.media_image_id IS 
    'ID da fotografia histórica do módulo de álbuns (somente quando tipo_fonte = foto_album)';
