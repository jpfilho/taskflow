-- =========================================
-- LIMPAR TABELAS TELEGRAM EXISTENTES
-- Execute este SQL ANTES da migration
-- =========================================

-- Remover políticas RLS
DROP POLICY IF EXISTS "Usuários podem ver e atualizar suas próprias identidades Telegram" ON telegram_identities;
DROP POLICY IF EXISTS "Usuários podem gerenciar suas próprias assinaturas Telegram" ON telegram_subscriptions;
DROP POLICY IF EXISTS "Usuários autenticados podem criar subscriptions para threads que têm acesso" ON telegram_subscriptions;
DROP POLICY IF EXISTS "Usuários autenticados podem ler subscriptions de threads que têm acesso" ON telegram_subscriptions;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar subscriptions de threads que têm acesso" ON telegram_subscriptions;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar subscriptions de threads que têm acesso" ON telegram_subscriptions;
DROP POLICY IF EXISTS "Apenas service_role pode inserir logs de entrega Telegram" ON telegram_delivery_logs;
DROP POLICY IF EXISTS "Ninguém pode ler logs de entrega Telegram" ON telegram_delivery_logs;

-- Remover triggers
DROP TRIGGER IF EXISTS handle_updated_at ON telegram_subscriptions;

-- Remover funções
DROP FUNCTION IF EXISTS can_access_thread(telegram_thread_type, text, uuid);
DROP FUNCTION IF EXISTS get_task_id_from_grupo_chat(uuid);
DROP FUNCTION IF EXISTS get_comunidade_id_from_grupo_chat(uuid);

-- Remover tabelas
DROP TABLE IF EXISTS telegram_delivery_logs CASCADE;
DROP TABLE IF EXISTS telegram_subscriptions CASCADE;
DROP TABLE IF EXISTS telegram_identities CASCADE;

-- Remover tipos ENUM
DROP TYPE IF EXISTS telegram_thread_type CASCADE;
DROP TYPE IF EXISTS telegram_mode_type CASCADE;

-- Remover colunas adicionadas na tabela mensagens (se existirem)
ALTER TABLE IF EXISTS mensagens DROP COLUMN IF EXISTS source;
ALTER TABLE IF EXISTS mensagens DROP COLUMN IF EXISTS telegram_metadata;

-- =========================================
-- VERIFICAR SE FOI REMOVIDO
-- =========================================

-- Esta query deve retornar 0 linhas após a limpeza
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename LIKE 'telegram%';
