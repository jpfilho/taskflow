-- ============================================
-- SQL PARA ADICIONAR NOVOS CAMPOS NA TABELA EXECUTORES
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- IMPORTANTE: As tabelas 'empresas' e 'funcoes' devem ser criadas ANTES desta

-- Adicionar novas colunas
ALTER TABLE executores
ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS matricula VARCHAR(50),
ADD COLUMN IF NOT EXISTS login VARCHAR(100),
ADD COLUMN IF NOT EXISTS nome_completo VARCHAR(255),
ADD COLUMN IF NOT EXISTS ramal VARCHAR(20),
ADD COLUMN IF NOT EXISTS telefone VARCHAR(20),
ADD COLUMN IF NOT EXISTS funcao_id UUID REFERENCES funcoes(id) ON DELETE SET NULL;

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_executores_empresa_id ON executores(empresa_id);
CREATE INDEX IF NOT EXISTS idx_executores_funcao_id ON executores(funcao_id);
CREATE INDEX IF NOT EXISTS idx_executores_matricula ON executores(matricula);
CREATE INDEX IF NOT EXISTS idx_executores_login ON executores(login);

-- Comentários nas novas colunas
COMMENT ON COLUMN executores.empresa_id IS 'ID da empresa associada (opcional)';
COMMENT ON COLUMN executores.matricula IS 'Matrícula do executor';
COMMENT ON COLUMN executores.login IS 'Login do executor';
COMMENT ON COLUMN executores.nome_completo IS 'Nome completo do executor';
COMMENT ON COLUMN executores.ramal IS 'Ramal do executor';
COMMENT ON COLUMN executores.telefone IS 'Telefone do executor';
COMMENT ON COLUMN executores.funcao_id IS 'ID da função associada (opcional)';

-- Verificar se as colunas foram adicionadas corretamente
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'executores'
ORDER BY ordinal_position;

