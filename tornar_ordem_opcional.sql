-- ============================================
-- SQL PARA TORNAR O CAMPO ORDEM OPCIONAL
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new
-- 
-- Este script torna o campo 'ordem' opcional (nullable) na tabela tasks

-- Remover constraint NOT NULL do campo ordem
ALTER TABLE tasks 
    ALTER COLUMN ordem DROP NOT NULL;

-- Verificar se a alteração foi aplicada
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'tasks' 
    AND column_name = 'ordem';

-- Comentário na coluna
COMMENT ON COLUMN tasks.ordem IS 'Ordem da tarefa (opcional)';

