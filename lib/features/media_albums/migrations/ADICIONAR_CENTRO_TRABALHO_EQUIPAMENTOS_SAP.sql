-- ============================================
-- Migração: centro_trabalho_responsavel em equipamentos_sap
-- ============================================
-- A tabela equipamentos_sap pode já ter esta coluna (ex.: DDL completo com
-- localizacao, sala, centro_trabalho_responsavel, etc.). Esta migração é
-- idempotente: ADD COLUMN IF NOT EXISTS e CREATE INDEX IF NOT EXISTS.
-- Usado para filtrar equipamentos/salas pelo centro de trabalho do usuário
-- (regional, divisão, segmento).
-- ============================================

ALTER TABLE public.equipamentos_sap
ADD COLUMN IF NOT EXISTS centro_trabalho_responsavel VARCHAR(100);

COMMENT ON COLUMN public.equipamentos_sap.centro_trabalho_responsavel IS
  'Centro de trabalho responsável (mesmo conceito de notas_sap). Usado para filtrar equipamentos/salas pelo perfil do usuário.';

-- Índice para filtros ILIKE (opcional, melhora performance)
CREATE INDEX IF NOT EXISTS idx_equipamentos_sap_centro_trabalho_responsavel
ON public.equipamentos_sap(centro_trabalho_responsavel);
