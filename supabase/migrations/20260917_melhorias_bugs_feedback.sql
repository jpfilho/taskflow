-- ============================================
-- Migration: Adiciona coluna feedback em melhorias_bugs
-- Data: 17/09/2026
-- Objetivo: Permitir que a equipe forneça feedback textual ao usuário que abriu a solicitação de melhoria ou bug.
-- ============================================

ALTER TABLE public.melhorias_bugs 
ADD COLUMN IF NOT EXISTS feedback TEXT;

COMMENT ON COLUMN public.melhorias_bugs.feedback IS 'Feedback ou resposta textual da equipe para o usuário solicitante.';
