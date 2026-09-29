-- ============================================
-- Migration: Adiciona coluna prazo em melhorias_bugs
-- Data: 17/09/2026
-- Objetivo: Permitir estipular prazo para resolução de solicitações de melhorias e bugs.
-- ============================================

ALTER TABLE public.melhorias_bugs 
ADD COLUMN IF NOT EXISTS prazo TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_melhorias_bugs_prazo ON public.melhorias_bugs(prazo);

COMMENT ON COLUMN public.melhorias_bugs.prazo IS 'Prazo limite estimado para a resolução da melhoria ou bug.';
