-- ============================================
-- SQL PARA ADICIONAR COLUNA COR NA TABELA STATUS
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Adicionar coluna cor na tabela status
ALTER TABLE status 
ADD COLUMN IF NOT EXISTS cor VARCHAR(7) DEFAULT '#2196F3';

-- Comentário na coluna
COMMENT ON COLUMN status.cor IS 'Cor do status em formato hexadecimal (ex: #FF5733)';

-- Atualizar registros existentes com uma cor padrão se necessário
UPDATE status 
SET cor = '#2196F3' 
WHERE cor IS NULL;

