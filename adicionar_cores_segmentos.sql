-- Adicionar colunas de cor aos segmentos
ALTER TABLE segmentos
ADD COLUMN IF NOT EXISTS cor TEXT,
ADD COLUMN IF NOT EXISTS cor_texto TEXT;

-- Comentários nas colunas
COMMENT ON COLUMN segmentos.cor IS 'Cor de fundo do segmento em formato hexadecimal (ex: #FF5733)';
COMMENT ON COLUMN segmentos.cor_texto IS 'Cor do texto do segmento em formato hexadecimal (ex: #FFFFFF)';
