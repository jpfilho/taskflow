-- ============================================
-- SQL PARA ADICIONAR COLUNA GPM EM CENTROS DE TRABALHO
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard

-- Adicionar coluna GPM (numérico, opcional)
ALTER TABLE centros_trabalho 
ADD COLUMN IF NOT EXISTS gpm INTEGER;

-- Comentário na coluna
COMMENT ON COLUMN centros_trabalho.gpm IS 'GPM (numérico)';
