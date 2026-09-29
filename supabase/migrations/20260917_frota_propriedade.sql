-- ==============================================================================
-- MIGRATION: Adicionar coluna de regime de propriedade na tabela public.frota
-- Opções permitidas: 'PROPRIO', 'LOCADO', 'TERCEIRO'
-- ==============================================================================

-- 1. Adicionar coluna propriedade com default 'PROPRIO'
ALTER TABLE public.frota 
  ADD COLUMN IF NOT EXISTS propriedade character varying(30) NOT NULL DEFAULT 'PROPRIO';

-- 2. Adicionar constraint de validação das opções aceitas
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'frota_propriedade_check'
  ) THEN
    ALTER TABLE public.frota 
      ADD CONSTRAINT frota_propriedade_check 
      CHECK (propriedade IN ('PROPRIO', 'LOCADO', 'TERCEIRO'));
  END IF;
END $$;

-- 3. Criar índice para performance em consultas e filtros
CREATE INDEX IF NOT EXISTS idx_frota_propriedade ON public.frota USING btree (propriedade);

-- 4. Notificar PostgREST para recarregar o schema da API
NOTIFY pgrst, 'reload schema';
