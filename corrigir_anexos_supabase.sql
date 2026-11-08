-- ==============================================================================
-- TASKFLOW: CORREÇÃO DE ANEXOS LEGADOS NO SUPABASE (SQL DIRETO)
-- ==============================================================================
-- Este script corrige os 15 arquivos de VÍDEO (MP4) que estavam salvos como '.jpg'
-- e os 29 arquivos PNG que estavam com extensão corrompida '.p_g'.
--
-- O script atualiza simultaneamente:
--   1. A tabela de metadados da aplicação: public.notas_sap_anexos
--   2. A tabela interna do Supabase Storage: storage.objects
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. CORREÇÃO DOS VÍDEOS MP4 IDENTIFICADOS (Eram gravados como imagem .jpg)
-- ------------------------------------------------------------------------------

-- Atualiza tabela da aplicação (public.notas_sap_anexos)
UPDATE public.notas_sap_anexos
SET 
    tipo_arquivo = 'video',
    extensao = 'mp4',
    mime_type = 'video/mp4',
    relevante_analise = TRUE,
    nome_arquivo = regexp_replace(nome_arquivo, '\.jpg$', '.mp4', 'i'),
    nome_original = regexp_replace(COALESCE(nome_original, nome_arquivo), '\.jpg$', '.mp4', 'i'),
    caminho_arquivo = regexp_replace(caminho_arquivo, '\.jpg$', '.mp4', 'i')
WHERE id IN (
    'dcd6c838-03a8-49e2-bc7f-ac3f879f761c', -- 11490220 (27.33 MB)
    '795f081c-0197-4351-9b16-194f84fcd9e2', -- 11369720 (26.50 MB)
    'c4cc7444-5282-48b6-85d1-c5bcd25c3f1b', -- 11391006 (14.11 MB)
    'efc9a9b5-adc4-4dea-a409-b3de781de748', -- 11463167 (12.45 MB)
    '40f3860c-c3e2-46db-9da2-7adc84c66171', -- 11446670 (10.07 MB)
    'ced997e3-e98f-4d50-9614-34401bb068b0', -- 11329958 (9.89 MB)
    'b462fe52-07ff-4032-8a9d-d02c94b7d631', -- 11527153 (9.29 MB)
    '53fd8b53-7b44-481e-a2cf-489244ad5e76', -- 11481690 (7.99 MB)
    '43e4ae15-ab6f-4d4f-9480-afe19e263262', -- 11467577 (7.95 MB)
    'c87363a1-36f2-4f99-8988-d480566f307a', -- 11506705 (7.85 MB)
    'bb6b52a0-ce87-4cb9-be12-16824e5cad9b', -- 11377582 (5.84 MB)
    'bf1c472b-ff85-45c3-9b7f-a6ce40eb76de', -- 11585041 (4.95 MB)
    'bc773475-7350-48be-bf09-b209452ce915', -- 11472842 (4.88 MB)
    '8ad3d82c-b2cf-499a-ae96-10ae69c5bd3d', -- 11496520 (4.80 MB)
    '3d288f0d-3e9a-443b-9d2f-3ef7e196126b'  -- 11486576 (4.79 MB)
);

-- Atualiza tabela do Storage (storage.objects) para manter o arquivo físico acessível
UPDATE storage.objects
SET 
    name = regexp_replace(name, '\.jpg$', '.mp4', 'i'),
    metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{mimetype}',
        '"video/mp4"'::jsonb
    )
WHERE bucket_id = 'notas-sap-anexos'
  AND (
      name LIKE '%11490220_Imagem1.jpg' OR
      name LIKE '%11369720_Imagem4.jpg' OR
      name LIKE '%11391006_Imagem1.jpg' OR
      name LIKE '%11463167_Imagem1.jpg' OR
      name LIKE '%11446670_Imagem1.jpg' OR
      name LIKE '%11329958_Imagem1.jpg' OR
      name LIKE '%11527153_Imagem1.jpg' OR
      name LIKE '%11481690_Imagem1.jpg' OR
      name LIKE '%11467577_Imagem1.jpg' OR
      name LIKE '%11506705_Imagem1.jpg' OR
      name LIKE '%11377582_Imagem2.jpg' OR
      name LIKE '%11585041_Imagem1.jpg' OR
      name LIKE '%11472842_Imagem1.jpg' OR
      name LIKE '%11496520_Imagem1.jpg' OR
      name LIKE '%11486576_Imagem1.jpg'
  );


-- ------------------------------------------------------------------------------
-- 2. CORREÇÃO DOS ARQUIVOS PNG CORROMPIDOS (Extensão '.p_g' -> '.png')
-- ------------------------------------------------------------------------------

-- Atualiza tabela da aplicação (public.notas_sap_anexos)
UPDATE public.notas_sap_anexos
SET 
    tipo_arquivo = 'imagem',
    extensao = 'png',
    mime_type = 'image/png',
    nome_arquivo = regexp_replace(nome_arquivo, '\.p_g$', '.png', 'i'),
    nome_original = regexp_replace(COALESCE(nome_original, nome_arquivo), '\.p_g$', '.png', 'i'),
    caminho_arquivo = regexp_replace(caminho_arquivo, '\.p_g$', '.png', 'i')
WHERE nome_arquivo ILIKE '%.p_g' OR extensao = 'p_g';

-- Atualiza tabela do Storage (storage.objects)
UPDATE storage.objects
SET 
    name = regexp_replace(name, '\.p_g$', '.png', 'i'),
    metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{mimetype}',
        '"image/png"'::jsonb
    )
WHERE bucket_id = 'notas-sap-anexos'
  AND name ILIKE '%.p_g';

COMMIT;

-- ------------------------------------------------------------------------------
-- 3. CONSULTA DE VERIFICAÇÃO PÓS-EXECUÇÃO
-- ------------------------------------------------------------------------------
SELECT 
    id,
    tipo_arquivo,
    extensao,
    mime_type,
    nome_arquivo,
    caminho_arquivo,
    ROUND(tamanho_bytes / 1024.0 / 1024.0, 2) AS tamanho_mb
FROM public.notas_sap_anexos
WHERE tipo_arquivo = 'video' OR extensao = 'png'
ORDER BY tamanho_bytes DESC
LIMIT 25;

