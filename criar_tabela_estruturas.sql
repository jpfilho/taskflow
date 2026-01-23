-- Tabela de Estruturas importadas do Excel "Estruturas.xlsx"
-- Colunas identificadas: LT, Estrutura, Família, Tipo, Progressiva, Vão (m),
-- Altura Útil (m), Deflexão, Equipe, Georeferência (lat), Georeferência (lon),
-- NUMERAÇÃO ANTIGA.

CREATE TABLE IF NOT EXISTS public.estruturas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lt TEXT NOT NULL,                    -- ex: BEATSA U1
  estrutura TEXT NOT NULL,             -- ex: 001/1
  familia TEXT,                        -- ex: AS230
  tipo TEXT,
  progressiva TEXT,                    -- manter como texto para flexibilidade
  vao_m NUMERIC(14,3),                 -- Vão (m)
  altura_util_m NUMERIC(14,3),         -- Altura Útil (m)
  deflexao TEXT,                       -- pode conter ângulos/observações
  equipe TEXT,                         -- time/responsável
  geo_lat TEXT,                        -- Georeferência (latitude)
  geo_lon TEXT,                        -- Georeferência (longitude)
  numeracao_antiga TEXT,               -- NUMERAÇÃO ANTIGA
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Garantir chave única para upsert (lt + estrutura)
ALTER TABLE public.estruturas
  ADD CONSTRAINT uq_estruturas_lt_estrutura UNIQUE (lt, estrutura);

CREATE INDEX IF NOT EXISTS idx_estruturas_lt ON public.estruturas(lt);
CREATE INDEX IF NOT EXISTS idx_estruturas_estrutura ON public.estruturas(estrutura);

COMMENT ON TABLE public.estruturas IS 'Estruturas de linhas de transmissão importadas do Excel Estruturas.xlsx';
