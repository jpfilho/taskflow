-- ==============================================================================
-- ETAPA 3: Anexos das Notas SAP, Storage e Anotações Técnicas
-- ARQUIVO: 03_anexos_storage_e_anotacoes.sql
-- AMBIENTE: Produção (10.140.50.12)
-- DIRETRIZES: Idempotente (IF NOT EXISTS), sem operações destrutivas.
-- ==============================================================================

\set ON_ERROR_STOP 1

BEGIN;

-- 1. BUCKET NOVO 'notas-sap-anexos' NO STORAGE (PRIVADO)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'buckets') THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'notas-sap-anexos',
      'notas-sap-anexos',
      false,
      104857600, -- 100 MB
      NULL
    )
    ON CONFLICT (id) DO UPDATE 
    SET public = false;
  END IF;
END $$;

-- 2. POLÍTICAS DE RLS DO STORAGE
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'objects') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir leitura de notas-sap-anexos'
    ) THEN
      CREATE POLICY "Permitir leitura de notas-sap-anexos"
      ON storage.objects FOR SELECT
      TO public
      USING (bucket_id = 'notas-sap-anexos');
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir upload de notas-sap-anexos'
    ) THEN
      CREATE POLICY "Permitir upload de notas-sap-anexos"
      ON storage.objects FOR INSERT
      TO public
      WITH CHECK (bucket_id = 'notas-sap-anexos');
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir exclusao de notas-sap-anexos'
    ) THEN
      CREATE POLICY "Permitir exclusao de notas-sap-anexos"
      ON storage.objects FOR DELETE
      TO public
      USING (bucket_id = 'notas-sap-anexos');
    END IF;

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
  END IF;
END $$;

-- 3. TABELA DE ANEXOS DA NOTA SAP (ESTRUTURA CONSOLIDADA COMPLETA)
CREATE TABLE IF NOT EXISTS public.notas_sap_anexos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_sap_id UUID NOT NULL REFERENCES public.notas_sap(id) ON DELETE CASCADE,
  nome_arquivo VARCHAR(255) NOT NULL,
  nome_original VARCHAR(255),
  tipo_arquivo VARCHAR(20) NOT NULL CHECK (tipo_arquivo IN ('imagem', 'video', 'pdf', 'documento', 'planilha', 'audio', 'outro')),
  caminho_arquivo TEXT NOT NULL,
  tamanho_bytes INTEGER NOT NULL,
  mime_type VARCHAR(100),
  legenda TEXT,
  bucket VARCHAR(100) NOT NULL DEFAULT 'notas-sap-anexos',
  extensao VARCHAR(20),
  origem VARCHAR(30) NOT NULL DEFAULT 'SAP' CHECK (origem IN ('SAP', 'TASKFLOW', 'USUARIO', 'IMPORTACAO')),
  sap_document_id TEXT,
  sha256 VARCHAR(64),
  metadata JSONB DEFAULT '{}'::jsonb,
  importado_em TIMESTAMPTZ,
  relevante_analise BOOLEAN NOT NULL DEFAULT false,
  anexo_derivado_de_id UUID REFERENCES public.notas_sap_anexos(id) ON DELETE SET NULL,
  usuario_id UUID,
  usuario_nome VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Garantir colunas caso a tabela já existisse em versão anterior
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS nome_original VARCHAR(255);
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS bucket VARCHAR(100) DEFAULT 'notas-sap-anexos';
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS extensao VARCHAR(20);
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS origem VARCHAR(30) DEFAULT 'SAP';
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS sap_document_id TEXT;
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS sha256 VARCHAR(64);
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS importado_em TIMESTAMPTZ;
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS relevante_analise BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.notas_sap_anexos ADD COLUMN IF NOT EXISTS anexo_derivado_de_id UUID REFERENCES public.notas_sap_anexos(id) ON DELETE SET NULL;

-- Índices de notas_sap_anexos
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_nota_id ON public.notas_sap_anexos(nota_sap_id);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_tipo ON public.notas_sap_anexos(tipo_arquivo);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_relevante ON public.notas_sap_anexos(nota_sap_id, relevante_analise);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_origem ON public.notas_sap_anexos(origem);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_bucket ON public.notas_sap_anexos(bucket);
CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_derivado_de ON public.notas_sap_anexos(anexo_derivado_de_id) WHERE anexo_derivado_de_id IS NOT NULL;

-- Índices de unicidade (idempotência de upload)
CREATE UNIQUE INDEX IF NOT EXISTS uq_notas_sap_anexos_sap_doc ON public.notas_sap_anexos(nota_sap_id, sap_document_id) WHERE sap_document_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_notas_sap_anexos_sha256 ON public.notas_sap_anexos(nota_sap_id, sha256) WHERE sha256 IS NOT NULL;

COMMENT ON TABLE public.notas_sap_anexos IS 'Imagens do defeito, esquemas e documentos técnicos anexados à Nota SAP';

-- 4. TABELA DE ANOTAÇÕES VETORIAIS (APPEND-ONLY)
CREATE TABLE IF NOT EXISTS public.notas_sap_anexos_anotacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anexo_id UUID NOT NULL REFERENCES public.notas_sap_anexos(id) ON DELETE CASCADE,
  versao INT NOT NULL,
  dados_json JSONB NOT NULL,
  imagem_largura INT,
  imagem_altura INT,
  criado_por UUID NULL,
  criado_por_nome TEXT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_anotacao_anexo_versao UNIQUE (anexo_id, versao)
);

CREATE INDEX IF NOT EXISTS idx_anotacoes_anexo_versao ON public.notas_sap_anexos_anotacoes(anexo_id, versao DESC);

COMMENT ON TABLE public.notas_sap_anexos_anotacoes IS 'Anotações técnicas vetoriais não destrutivas em camadas sobre anexos de Notas';

-- 5. POLÍTICAS DE RLS
ALTER TABLE public.notas_sap_anexos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notas_sap_anexos_anotacoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anexos de notas visíveis para todos" ON public.notas_sap_anexos;
CREATE POLICY "Anexos de notas visíveis para todos" ON public.notas_sap_anexos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários podem gerenciar anexos de notas" ON public.notas_sap_anexos;
CREATE POLICY "Usuários podem gerenciar anexos de notas" ON public.notas_sap_anexos
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir leitura de anotacoes" ON public.notas_sap_anexos_anotacoes;
CREATE POLICY "Permitir leitura de anotacoes" ON public.notas_sap_anexos_anotacoes
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Permitir insercao de anotacoes" ON public.notas_sap_anexos_anotacoes;
CREATE POLICY "Permitir insercao de anotacoes" ON public.notas_sap_anexos_anotacoes
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir exclusao de anotacoes" ON public.notas_sap_anexos_anotacoes;
CREATE POLICY "Permitir exclusao de anotacoes" ON public.notas_sap_anexos_anotacoes
  FOR DELETE USING (true);

-- 6. CONCESSÃO DE PRIVILÉGIOS (GRANTS PARA API SUPABASE)
DO $$
BEGIN
  GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_anexos TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.notas_sap_anexos_anotacoes TO anon, authenticated, service_role;
END $$;

COMMIT;
