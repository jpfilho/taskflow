-- ==============================================================================
-- ROLLBACK SEGURO FASE 2: GESTÃO INTEGRADA DE APOIOS OPERACIONAIS
-- DATA: 2026-11-17
-- ==============================================================================
-- PROCEDIMENTO DIFERENCIADO DE REVERSÃO:
--
-- CENÁRIO A — ROLLBACK APÓS EXISTÊNCIA DE REGISTROS OPERACIONAIS:
--   1. NÃO executar DROP imediato antes de preservar os dados.
--   2. Desativar imediatamente o acesso à funcionalidade:
--        REVOKE ALL ON public.tasks_apoios_solicitacoes,
--          public.tasks_apoios_solicitacoes_periodos,
--          public.tasks_apoios_vinculos,
--          public.tasks_apoios_historico FROM anon, authenticated;
--   3. Exportar os dados para arquivo de auditoria antes da remoção:
--        \copy public.tasks_apoios_solicitacoes TO 'backup_solicitacoes.csv' CSV HEADER;
--        \copy public.tasks_apoios_vinculos TO 'backup_vinculos.csv' CSV HEADER;
--        \copy public.tasks_apoios_historico TO 'backup_historico.csv' CSV HEADER;
--
-- CENÁRIO B — ROLLBACK ANTES DA UTILIZAÇÃO OPERACIONAL (LIMPEZA CONTROLADA):
--   Executar o bloco transacional abaixo para remover apenas as estruturas
--   adicionadas na Fase 2, sem afetar public.tasks ou dados existentes.
-- ==============================================================================

BEGIN;

-- 1. Remover trigger anexado à tabela existente public.tasks
DROP TRIGGER IF EXISTS trg_preservar_apoios_antes_delete_task ON public.tasks;

-- 2. Remover views consolidadas
DROP VIEW IF EXISTS public.v_tasks_apoios_resumo_task CASCADE;
DROP VIEW IF EXISTS public.v_tasks_apoios_situacao CASCADE;

-- 3. Remover triggers das tabelas de apoio
DROP TRIGGER IF EXISTS trg_after_vinculo_apoio_hist ON public.tasks_apoios_vinculos;
DROP TRIGGER IF EXISTS trg_before_vinculo_apoio ON public.tasks_apoios_vinculos;
DROP TRIGGER IF EXISTS trg_after_solicitacao_apoio_hist ON public.tasks_apoios_solicitacoes;
DROP TRIGGER IF EXISTS trg_before_solicitacao_apoio ON public.tasks_apoios_solicitacoes;
DROP TRIGGER IF EXISTS trg_bloquear_mutacao_historico_apoio ON public.tasks_apoios_historico;

-- 4. Remover funções criadas
DROP FUNCTION IF EXISTS public.fn_preservar_apoios_antes_delete_task();
DROP FUNCTION IF EXISTS public.fn_after_vinculo_apoio_hist();
DROP FUNCTION IF EXISTS public.fn_before_vinculo_apoio();
DROP FUNCTION IF EXISTS public.fn_after_solicitacao_apoio_hist();
DROP FUNCTION IF EXISTS public.fn_before_solicitacao_apoio();
DROP FUNCTION IF EXISTS public.fn_validar_escopo_organizacional_apoio(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS public.fn_bloquear_mutacao_historico_apoio();

-- 5. Remover tabelas na ordem correta de dependências
DROP TABLE IF EXISTS public.tasks_apoios_historico;
DROP TABLE IF EXISTS public.tasks_apoios_vinculos;
DROP TABLE IF EXISTS public.tasks_apoios_solicitacoes_periodos;
DROP TABLE IF EXISTS public.tasks_apoios_solicitacoes;
DROP TABLE IF EXISTS public.tasks_apoios_tipos;

NOTIFY pgrst, 'reload schema';

COMMIT;

