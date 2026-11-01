-- ==============================================================================
-- MIGRATION: 20261029_suporte_anexos_sap.sql
-- DESCRIÇÃO: Suporte aprimorado aos anexos das Notas SAP (Storage + Metadados +
--            Idempotência + Relevância para Análise Técnica).
-- DIRETRIZES: Idempotente, retrocompatível, sem recriação de tabela, sem perda de dados.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CRIAR BUCKET NOVO 'notas-sap-anexos' (PRIVADO)
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'notas-sap-anexos',
  'notas-sap-anexos',
  false, -- Privado: acesso aos binários estritamente via Signed URL
  104857600, -- 100 MB limite conservador
  NULL -- Permite MIME types da amostra SAP sem restrições arbitrárias
)
ON CONFLICT (id) DO UPDATE 
SET public = false;

-- ------------------------------------------------------------------------------
-- 2. POLÍTICAS DE RLS DO STORAGE (Compatibilidade com papel anon / public atual)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  -- Leitura (SELECT)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir leitura de notas-sap-anexos'
  ) THEN
    CREATE POLICY "Permitir leitura de notas-sap-anexos"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'notas-sap-anexos');
  END IF;

  -- Upload (INSERT)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir upload de notas-sap-anexos'
  ) THEN
    CREATE POLICY "Permitir upload de notas-sap-anexos"
    ON storage.objects FOR INSERT
    TO public
    WITH CHECK (bucket_id = 'notas-sap-anexos');
  END IF;

  -- Exclusão (DELETE)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir exclusao de notas-sap-anexos'
  ) THEN
    CREATE POLICY "Permitir exclusao de notas-sap-anexos"
    ON storage.objects FOR DELETE
    TO public
    USING (bucket_id = 'notas-sap-anexos');
  END IF;

  -- Atualização (UPDATE)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir atualizacao de notas-sap-anexos'
  ) THEN
    CREATE POLICY "Permitir atualizacao de notas-sap-anexos"
    ON storage.objects FOR UPDATE
    TO public
    USING (bucket_id = 'notas-sap-anexos')
    WITH CHECK (bucket_id = 'notas-sap-anexos');
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. EVOLUÇÃO ESTRUTURAL DA TABELA public.notas_sap_anexos
-- ------------------------------------------------------------------------------

-- 3.1. Coluna 'nome_original'
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS nome_original VARCHAR(255);

-- 3.2. Coluna 'bucket' com backfill estrito para manter arquivos legados em 'anexos-tarefas'
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS bucket VARCHAR(100);

UPDATE public.notas_sap_anexos
SET bucket = 'anexos-tarefas'
WHERE bucket IS NULL;

ALTER TABLE public.notas_sap_anexos
ALTER COLUMN bucket SET DEFAULT 'notas-sap-anexos';

ALTER TABLE public.notas_sap_anexos
ALTER COLUMN bucket SET NOT NULL;

-- 3.3. Coluna 'extensao'
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS extensao VARCHAR(20);

-- 3.4. Coluna 'origem' com backfill conservador para 'TASKFLOW' em registros antigos
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS origem VARCHAR(30);

UPDATE public.notas_sap_anexos
SET origem = 'TASKFLOW'
WHERE origem IS NULL;

ALTER TABLE public.notas_sap_anexos
ALTER COLUMN origem SET DEFAULT 'SAP';

ALTER TABLE public.notas_sap_anexos
ALTER COLUMN origem SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'chk_notas_sap_anexos_origem' AND conrelid = 'public.notas_sap_anexos'::regclass
  ) THEN
    ALTER TABLE public.notas_sap_anexos
    ADD CONSTRAINT chk_notas_sap_anexos_origem 
    CHECK (origem IN ('SAP', 'TASKFLOW', 'USUARIO', 'IMPORTACAO'));
  END IF;
END $$;

-- 3.5. Coluna 'sap_document_id' (TEXT para máxima compatibilidade com IDs do SAP)
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS sap_document_id TEXT;

-- 3.6. Coluna 'sha256'
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS sha256 VARCHAR(64);

-- 3.7. Coluna 'metadata' JSONB
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- 3.8. Coluna 'importado_em'
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS importado_em TIMESTAMPTZ;

-- 3.9. Coluna 'relevante_analise'
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS relevante_analise BOOLEAN NOT NULL DEFAULT false;

-- 3.10. Expandir CHECK de 'tipo_arquivo'
DO $$
DECLARE
  v_conname text;
BEGIN
  FOR v_conname IN (
    SELECT conname 
    FROM pg_constraint 
    WHERE conrelid = 'public.notas_sap_anexos'::regclass 
      AND contype = 'c' 
      AND pg_get_constraintdef(oid) LIKE '%tipo_arquivo%'
  ) LOOP
    EXECUTE 'ALTER TABLE public.notas_sap_anexos DROP CONSTRAINT IF EXISTS ' || quote_ident(v_conname);
  END LOOP;
END $$;

ALTER TABLE public.notas_sap_anexos
ADD CONSTRAINT chk_notas_sap_anexos_tipo_arquivo
CHECK (tipo_arquivo IN ('imagem', 'video', 'pdf', 'documento', 'planilha', 'audio', 'outro'));

-- ------------------------------------------------------------------------------
-- 4. ÍNDICES DE PERFORMANCE E IDEMPOTÊNCIA
-- ------------------------------------------------------------------------------

-- Idempotência 1: por SAP Document ID
CREATE UNIQUE INDEX IF NOT EXISTS uq_notas_sap_anexos_sap_doc 
ON public.notas_sap_anexos(nota_sap_id, sap_document_id) 
WHERE sap_document_id IS NOT NULL;

-- Idempotência 2: por hash de integridade SHA-256
CREATE UNIQUE INDEX IF NOT EXISTS uq_notas_sap_anexos_sha256 
ON public.notas_sap_anexos(nota_sap_id, sha256) 
WHERE sha256 IS NOT NULL;

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_relevante 
ON public.notas_sap_anexos(nota_sap_id, relevante_analise);

CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_origem 
ON public.notas_sap_anexos(origem);

CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_bucket 
ON public.notas_sap_anexos(bucket);
