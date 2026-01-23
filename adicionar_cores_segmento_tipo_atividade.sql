-- Adicionar colunas de cor de segmento aos tipos de atividade
ALTER TABLE tipos_atividade
ADD COLUMN IF NOT EXISTS cor_segmento TEXT,
ADD COLUMN IF NOT EXISTS cor_texto_segmento TEXT;

-- Comentários nas colunas
COMMENT ON COLUMN tipos_atividade.cor_segmento IS 'Cor de fundo do segmento em formato hexadecimal (ex: #FF5733)';
COMMENT ON COLUMN tipos_atividade.cor_texto_segmento IS 'Cor do texto do segmento em formato hexadecimal (ex: #FFFFFF)';
