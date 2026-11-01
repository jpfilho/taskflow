-- ==============================================================================
-- MIGRATION: 20261101_suporte_evidencias_anexos_historicos.sql
-- DESCRIÇÃO: Habilita anexo_nota_historica como terceira fonte formal de evidências.
--            Reforça a integridade referencial de anexo_id para ON DELETE RESTRICT.
-- AMBIENTE: DEV
-- PRINCÍPIOS:
--   - Não duplicar imagens no Storage (arquivos permanecem na Nota histórica original).
--   - Integridade estrita: CHECK constraint assegura exclusividade mútua entre as 3 fontes.
--   - Proteção de exclusão: anexo_id ON DELETE RESTRICT impede que anexos em uso como
--     evidências técnicas (da própria nota ou de notas históricas) sejam deletados.
--   - Unicidade: 1 representação por anexo por seção técnica (índice parcial).
-- ==============================================================================

BEGIN;

-- 1. Substituir CHECK constraint para incorporar anexo_nota_historica
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
        OR
        (
            tipo_fonte = 'anexo_nota_historica' 
            AND anexo_id IS NOT NULL 
            AND media_image_id IS NULL
        )
    );

-- 2. Criar índice único parcial para anexo_nota_historica (uma representação por anexo/seção)
CREATE UNIQUE INDEX IF NOT EXISTS uq_evidencia_anexo_historico_secao
    ON public.notas_sap_analise_evidencias (nota_sap_id, anexo_id, tipo_vinculo)
    WHERE tipo_fonte = 'anexo_nota_historica';

-- 3. Atualizar FK de anexo_id para ON DELETE RESTRICT (proteção de evidências formais)
ALTER TABLE public.notas_sap_analise_evidencias 
    DROP CONSTRAINT IF EXISTS notas_sap_analise_evidencias_anexo_id_fkey;

ALTER TABLE public.notas_sap_analise_evidencias 
    DROP CONSTRAINT IF EXISTS fk_evidencia_anexo_id;

ALTER TABLE public.notas_sap_analise_evidencias 
    ADD CONSTRAINT fk_evidencia_anexo_id 
    FOREIGN KEY (anexo_id) 
    REFERENCES public.notas_sap_anexos(id) 
    ON DELETE RESTRICT;

-- 4. Comentário documental no schema
COMMENT ON COLUMN public.notas_sap_analise_evidencias.tipo_fonte IS 
    'Fonte da evidência: anexo_nota (Nota atual), foto_album (media_images) ou anexo_nota_historica (anexo referencial de Nota anterior)';

COMMIT;
