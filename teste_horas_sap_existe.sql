-- Verificar se a tabela horas_sap existe
SELECT EXISTS (
    SELECT 1 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'horas_sap'
) AS tabela_existe;

-- Se a resposta for 't' ou 'true', a tabela existe
-- Se for 'f' ou 'false', a tabela NÃO existe
