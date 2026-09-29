-- ==============================================================================
-- MIGRATION: 20260917_divisoes_regionais.sql
-- DESCRIPTION: Suporte a Divisão em Múltiplas Regionais (N:N com divisoes_regionais)
-- BACKFILL IDEMPOTENTE & POLÍTICAS DE RLS
-- ==============================================================================

-- 1. CRIAR TABELA RELACIONAL divisoes_regionais
CREATE TABLE IF NOT EXISTS public.divisoes_regionais (
    divisao_id UUID NOT NULL,
    regional_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT divisoes_regionais_pkey
        PRIMARY KEY (divisao_id, regional_id),

    CONSTRAINT divisoes_regionais_divisao_fkey
        FOREIGN KEY (divisao_id)
        REFERENCES public.divisoes(id)
        ON DELETE CASCADE,

    CONSTRAINT divisoes_regionais_regional_fkey
        FOREIGN KEY (regional_id)
        REFERENCES public.regionais(id)
        ON DELETE CASCADE
);

-- 2. CRIAR ÍNDICES DE PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_divisoes_regionais_divisao_id
    ON public.divisoes_regionais(divisao_id);

CREATE INDEX IF NOT EXISTS idx_divisoes_regionais_regional_id
    ON public.divisoes_regionais(regional_id);

-- 3. BACKFILL IDEMPOTENTE DOS VÍNCULOS EXISTENTES
-- Migra todas as relações históricas de divisoes.regional_id para divisoes_regionais
INSERT INTO public.divisoes_regionais (
    divisao_id,
    regional_id
)
SELECT
    id,
    regional_id
FROM public.divisoes
WHERE regional_id IS NOT NULL
ON CONFLICT (divisao_id, regional_id) DO NOTHING;

-- 4. HABILITAR E CONFIGURAR ROW LEVEL SECURITY (RLS)
ALTER TABLE public.divisoes_regionais ENABLE ROW LEVEL SECURITY;

-- Política de leitura: todos autenticados/anon podem consultar os relacionamentos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'divisoes_regionais' 
        AND policyname = 'Permitir leitura de divisoes_regionais'
    ) THEN
        CREATE POLICY "Permitir leitura de divisoes_regionais"
            ON public.divisoes_regionais
            FOR SELECT
            USING (true);
    END IF;
END
$$;

-- Política de inserção: usuários autenticados podem inserir relacionamentos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'divisoes_regionais' 
        AND policyname = 'Permitir insercao em divisoes_regionais'
    ) THEN
        CREATE POLICY "Permitir insercao em divisoes_regionais"
            ON public.divisoes_regionais
            FOR INSERT
            WITH CHECK (true);
    END IF;
END
$$;

-- Política de exclusão: usuários autenticados podem remover relacionamentos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'divisoes_regionais' 
        AND policyname = 'Permitir exclusao em divisoes_regionais'
    ) THEN
        CREATE POLICY "Permitir exclusao em divisoes_regionais"
            ON public.divisoes_regionais
            FOR DELETE
            USING (true);
    END IF;
END
$$;

-- ==============================================================================
-- PLANO DE ROLLBACK (EM CASO DE NECESSIDADE):
-- ==============================================================================
-- Como divisoes.regional_id NÃO foi removido, o rollback consiste em:
-- 1. DROP TABLE IF EXISTS public.divisoes_regionais CASCADE;
-- Nenhum dado de tarefas ou divisões é perdido.
-- ==============================================================================
