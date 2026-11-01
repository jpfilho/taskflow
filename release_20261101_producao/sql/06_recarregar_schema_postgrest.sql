-- ==============================================================================
-- ETAPA 6: Recarregamento de Cache de Schema do PostgREST
-- ARQUIVO: 06_recarregar_schema_postgrest.sql
-- AMBIENTE: Produção (10.140.50.12)
-- ==============================================================================

NOTIFY pgrst, 'reload schema';
