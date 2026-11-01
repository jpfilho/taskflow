-- ==============================================================================
-- MIGRATION: 20261030_suporte_anotacoes_anexos_sap.sql
-- DESCRIÇÃO: Fase 3 - Anotação Técnica, Edição Não Destrutiva e Evidências Derivadas.
--            Suporte a anotações vetoriais (append-only) e auto-relacionamento de
--            evidências derivadas em public.notas_sap_anexos.
-- DIRETRIZES: Idempotente, retrocompatível, sem dados duplicados, sem dependência de auth.users.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. EVOLUÇÃO EM public.notas_sap_anexos (Auto-relacionamento Derivada -> Original)
-- ------------------------------------------------------------------------------
ALTER TABLE public.notas_sap_anexos
ADD COLUMN IF NOT EXISTS anexo_derivado_de_id UUID
REFERENCES public.notas_sap_anexos(id)
ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_notas_sap_anexos_derivado_de
ON public.notas_sap_anexos(anexo_derivado_de_id)
WHERE anexo_derivado_de_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 2. TABELA DEDICADA DE ANOTAÇÕES VETORIAIS (APPEND-ONLY)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notas_sap_anexos_anotacoes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anexo_id UUID NOT NULL REFERENCES public.notas_sap_anexos(id) ON DELETE CASCADE,
  versao INT NOT NULL,
  dados_json JSONB NOT NULL,
  imagem_largura INT,
  imagem_altura INT,
  criado_por UUID NULL,
  criado_por_nome TEXT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT uq_anotacao_anexo_versao UNIQUE (anexo_id, versao)
);

-- Índice para ordenação e busca rápida da versão mais recente
CREATE INDEX IF NOT EXISTS idx_anotacoes_anexo_versao 
ON public.notas_sap_anexos_anotacoes(anexo_id, versao DESC);

-- ------------------------------------------------------------------------------
-- 3. POLÍTICAS DE RLS (Compatibilidade com cliente atual anon / public)
-- ------------------------------------------------------------------------------
ALTER TABLE public.notas_sap_anexos_anotacoes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  -- Leitura
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'notas_sap_anexos_anotacoes' AND policyname = 'Permitir leitura de anotacoes'
  ) THEN
    CREATE POLICY "Permitir leitura de anotacoes"
    ON public.notas_sap_anexos_anotacoes FOR SELECT
    TO public
    USING (true);
  END IF;

  -- Inserção
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'notas_sap_anexos_anotacoes' AND policyname = 'Permitir insercao de anotacoes'
  ) THEN
    CREATE POLICY "Permitir insercao de anotacoes"
    ON public.notas_sap_anexos_anotacoes FOR INSERT
    TO public
    WITH CHECK (true);
  END IF;

  -- Exclusão (apenas para limpeza explícita de anexo pai)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'notas_sap_anexos_anotacoes' AND policyname = 'Permitir exclusao de anotacoes'
  ) THEN
    CREATE POLICY "Permitir exclusao de anotacoes"
    ON public.notas_sap_anexos_anotacoes FOR DELETE
    TO public
    USING (true);
  END IF;
END $$;
