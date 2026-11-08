-- ==============================================================================
-- ROLLBACK: 20261102_previsoes_individuais_notas_sap_rollback.sql
-- DESCRIÇÃO: Reversão completa das tabelas e triggers de previsões individuais
-- ==============================================================================

DROP TRIGGER IF EXISTS trigger_historico_previsao_nota ON public.notas_sap_previsoes;
DROP TRIGGER IF EXISTS trigger_previsao_nota_updated ON public.notas_sap_previsoes;
DROP FUNCTION IF EXISTS public.handle_historico_previsao_nota();
DROP FUNCTION IF EXISTS public.handle_updated_at_previsao_nota();

DROP TABLE IF EXISTS public.notas_sap_previsoes_hist CASCADE;
DROP TABLE IF EXISTS public.notas_sap_previsoes CASCADE;

NOTIFY pgrst, 'reload schema';
