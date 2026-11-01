-- ==============================================================================
-- MIGRATION: 20261019_adicionar_valor_pv_notas_sap_analises.sql
-- DESCRIÇÃO: Adiciona campo de Parcela Variável (PV) em notas_sap_analises
-- OBJETIVO: Permitir que analistas informem o valor financeiro estimado de PV
--           associado ao desligamento do ativo ou função de transmissão (FT).
-- ==============================================================================

ALTER TABLE public.notas_sap_analises
ADD COLUMN IF NOT EXISTS valor_pv NUMERIC(14,2);

COMMENT ON COLUMN public.notas_sap_analises.valor_pv IS 'Valor financeiro estimado da Parcela Variável (PV) em caso de desligamento';
