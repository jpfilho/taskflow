-- ==============================================================================
-- ROLLBACK SELETIVO E SEGURO DAS MIGRATIONS DE NOTAS SAP (OUTUBRO/NOVEMBRO 2026)
-- ARQUIVO: rollback_migracao_notas_sap.sql
-- AMBIENTE: Produção (10.140.50.12)
-- DIRETRIZ: Reverte EXCLUSIVAMENTE as novas estruturas criadas nas migrations
--           de outubro/novembro 2026, preservando INTEGRALMENTE os dados de
--           notas_sap, tasks, ordens, executores e demais tabelas legadas.
-- ATENÇÃO: NUNCA utilize pg_restore --clean sobre o banco ativo, pois isso
--          apagaria tarefas e alterações ocorridas após o horário do backup.
-- ==============================================================================

\set ON_ERROR_STOP 1

BEGIN;

\echo 'Iniciando rollback seguro das estruturas de Notas SAP...'

-- 1. Remoção de Vínculos e Tags
DROP TABLE IF EXISTS public.notas_sap_tags_vinculos CASCADE;
DROP TABLE IF EXISTS public.notas_sap_tags CASCADE;
DROP FUNCTION IF EXISTS public.trg_fn_notas_sap_tags_normalizar() CASCADE;

-- 2. Remoção de Evidências Técnicas
DROP TABLE IF EXISTS public.notas_sap_analise_evidencias CASCADE;

-- 3. Remoção de Anotações e Anexos
DROP TABLE IF EXISTS public.notas_sap_anexos_anotacoes CASCADE;
DROP TABLE IF EXISTS public.notas_sap_anexos CASCADE;

-- 4. Remoção de Grupos de Previsão e Histórico
DROP TABLE IF EXISTS public.notas_sap_grupos_previsoes_hist CASCADE;
DROP TABLE IF EXISTS public.notas_sap_grupos_itens CASCADE;
DROP TABLE IF EXISTS public.notas_sap_grupos CASCADE;
DROP FUNCTION IF EXISTS public.handle_historico_previsao_grupo() CASCADE;
DROP FUNCTION IF EXISTS public.check_reativacao_grupo() CASCADE;
DROP FUNCTION IF EXISTS public.check_nota_em_grupo_ativo() CASCADE;
DROP FUNCTION IF EXISTS public.handle_updated_at_notas_grupos() CASCADE;

-- 5. Remoção de Comentários, Materiais e Análises
DROP TABLE IF EXISTS public.notas_sap_comentarios CASCADE;
DROP TABLE IF EXISTS public.notas_sap_analise_materiais CASCADE;
DROP TABLE IF EXISTS public.notas_sap_analises CASCADE;
DROP FUNCTION IF EXISTS public.handle_updated_at_notas_analise() CASCADE;

-- 6. Recarregar cache do PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;

\echo '✅ Rollback seletivo concluído com sucesso. Estruturas antigas preservadas.'
