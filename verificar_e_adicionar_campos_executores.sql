-- ============================================
-- SQL PARA VERIFICAR E ADICIONAR CAMPOS NA TABELA EXECUTORES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: As tabelas 'empresas' e 'funcoes' devem ser criadas ANTES desta

-- Verificar e adicionar empresa_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'executores' AND column_name = 'empresa_id'
  ) THEN
    ALTER TABLE executores
    ADD COLUMN empresa_id UUID REFERENCES empresas(id) ON DELETE SET NULL;
    
    CREATE INDEX IF NOT EXISTS idx_executores_empresa_id ON executores(empresa_id);
    
    RAISE NOTICE 'Coluna empresa_id adicionada com sucesso';
  ELSE
    RAISE NOTICE 'Coluna empresa_id já existe';
  END IF;
END $$;

-- Verificar e adicionar matricula
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'executores' AND column_name = 'matricula'
  ) THEN
    ALTER TABLE executores ADD COLUMN matricula VARCHAR(50);
    CREATE INDEX IF NOT EXISTS idx_executores_matricula ON executores(matricula);
    RAISE NOTICE 'Coluna matricula adicionada com sucesso';
  ELSE
    RAISE NOTICE 'Coluna matricula já existe';
  END IF;
END $$;

-- Verificar e adicionar login
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'executores' AND column_name = 'login'
  ) THEN
    ALTER TABLE executores ADD COLUMN login VARCHAR(100);
    CREATE INDEX IF NOT EXISTS idx_executores_login ON executores(login);
    RAISE NOTICE 'Coluna login adicionada com sucesso';
  ELSE
    RAISE NOTICE 'Coluna login já existe';
  END IF;
END $$;

-- Verificar e adicionar nome_completo
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'executores' AND column_name = 'nome_completo'
  ) THEN
    ALTER TABLE executores ADD COLUMN nome_completo VARCHAR(255);
    RAISE NOTICE 'Coluna nome_completo adicionada com sucesso';
  ELSE
    RAISE NOTICE 'Coluna nome_completo já existe';
  END IF;
END $$;

-- Verificar e adicionar ramal
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'executores' AND column_name = 'ramal'
  ) THEN
    ALTER TABLE executores ADD COLUMN ramal VARCHAR(20);
    RAISE NOTICE 'Coluna ramal adicionada com sucesso';
  ELSE
    RAISE NOTICE 'Coluna ramal já existe';
  END IF;
END $$;

-- Verificar e adicionar telefone
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'executores' AND column_name = 'telefone'
  ) THEN
    ALTER TABLE executores ADD COLUMN telefone VARCHAR(20);
    RAISE NOTICE 'Coluna telefone adicionada com sucesso';
  ELSE
    RAISE NOTICE 'Coluna telefone já existe';
  END IF;
END $$;

-- Verificar e adicionar funcao_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'executores' AND column_name = 'funcao_id'
  ) THEN
    ALTER TABLE executores
    ADD COLUMN funcao_id UUID REFERENCES funcoes(id) ON DELETE SET NULL;
    
    CREATE INDEX IF NOT EXISTS idx_executores_funcao_id ON executores(funcao_id);
    
    RAISE NOTICE 'Coluna funcao_id adicionada com sucesso';
  ELSE
    RAISE NOTICE 'Coluna funcao_id já existe';
  END IF;
END $$;

-- Adicionar comentários nas novas colunas
COMMENT ON COLUMN executores.empresa_id IS 'ID da empresa associada (opcional)';
COMMENT ON COLUMN executores.matricula IS 'Matrícula do executor';
COMMENT ON COLUMN executores.login IS 'Login do executor';
COMMENT ON COLUMN executores.nome_completo IS 'Nome completo do executor';
COMMENT ON COLUMN executores.ramal IS 'Ramal do executor';
COMMENT ON COLUMN executores.telefone IS 'Telefone do executor';
COMMENT ON COLUMN executores.funcao_id IS 'ID da função associada (opcional)';

-- Verificar se todas as colunas foram adicionadas corretamente
SELECT
  column_name,
  data_type,
  is_nullable,
  character_maximum_length
FROM information_schema.columns
WHERE table_name = 'executores'
ORDER BY ordinal_position;

