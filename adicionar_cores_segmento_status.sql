-- Adicionar colunas de cor de segmento aos status
ALTER TABLE status
ADD COLUMN IF NOT EXISTS cor_segmento TEXT,
ADD COLUMN IF NOT EXISTS cor_texto_segmento TEXT;

-- Comentários nas colunas
COMMENT ON COLUMN status.cor_segmento IS 'Cor de fundo do segmento em formato hexadecimal (ex: #FF5733)';
COMMENT ON COLUMN status.cor_texto_segmento IS 'Cor do texto do segmento em formato hexadecimal (ex: #FFFFFF)';
