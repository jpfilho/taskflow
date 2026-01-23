-- Adicionar coluna local_instalacao_sap na tabela locais
-- Campo não obrigatório para armazenar o Local da Instalação SAP

-- Verificar se a coluna já existe antes de adicionar
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'locais' 
        AND column_name = 'local_instalacao_sap'
    ) THEN
        ALTER TABLE public.locais
        ADD COLUMN local_instalacao_sap VARCHAR(50) NULL;
        
        COMMENT ON COLUMN public.locais.local_instalacao_sap IS 'Local da Instalação SAP (exemplo: H-S-SAAA). Campo opcional.';
        
        RAISE NOTICE 'Coluna local_instalacao_sap adicionada com sucesso na tabela locais.';
    ELSE
        RAISE NOTICE 'Coluna local_instalacao_sap já existe na tabela locais.';
    END IF;
END $$;

-- Recarregar o schema do PostgREST para que a nova coluna seja reconhecida
NOTIFY pgrst, 'reload schema';
