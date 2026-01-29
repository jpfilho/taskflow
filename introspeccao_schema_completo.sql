-- ============================================
-- INTROSPECÇÃO COMPLETA DO SCHEMA SUPABASE
-- ============================================
-- Execute este script no Supabase SQL Editor para mapear:
-- - Tabelas do schema public
-- - Colunas e tipos
-- - Primary Keys (PKs)
-- - Foreign Keys (FKs)
-- - Índices
-- ============================================

-- ============================================
-- 1. LISTAR TODAS AS TABELAS DO SCHEMA PUBLIC
-- ============================================
SELECT 
    schemaname,
    tablename,
    tableowner,
    hasindexes,
    hasrules,
    hastriggers
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================
-- 2. COLUNAS E TIPOS DE TODAS AS TABELAS
-- ============================================
SELECT 
    t.table_schema,
    t.table_name,
    c.column_name,
    c.data_type,
    c.character_maximum_length,
    c.is_nullable,
    c.column_default,
    c.ordinal_position
FROM information_schema.tables t
JOIN information_schema.columns c 
    ON t.table_schema = c.table_schema 
    AND t.table_name = c.table_name
WHERE t.table_schema = 'public'
    AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name, c.ordinal_position;

-- ============================================
-- 3. PRIMARY KEYS (PKs)
-- ============================================
SELECT
    tc.table_schema,
    tc.table_name,
    kcu.column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.ordinal_position;

-- ============================================
-- 4. FOREIGN KEYS (FKs) - RELACIONAMENTOS
-- ============================================
SELECT
    tc.table_schema,
    tc.table_name,
    kcu.column_name,
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name,
    rc.update_rule,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
    AND tc.table_schema = rc.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.ordinal_position;

-- ============================================
-- 5. ÍNDICES (INCLUDING UNIQUE INDEXES)
-- ============================================
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef,
    CASE 
        WHEN indexdef LIKE '%UNIQUE%' THEN 'UNIQUE'
        ELSE 'NORMAL'
    END AS index_type
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- ============================================
-- 6. TABELAS ESPECÍFICAS DO CHAT/TELEGRAM
-- ============================================
-- Verificar se existem e mostrar estrutura detalhada

-- 6.1. Tabela MENSAGENS
SELECT 
    'MENSAGENS' AS tabela,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'mensagens'
ORDER BY ordinal_position;

-- 6.2. Tabela GRUPOS_CHAT
SELECT 
    'GRUPOS_CHAT' AS tabela,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'grupos_chat'
ORDER BY ordinal_position;

-- 6.3. Tabela TELEGRAM_DELIVERY_LOGS
SELECT 
    'TELEGRAM_DELIVERY_LOGS' AS tabela,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'telegram_delivery_logs'
ORDER BY ordinal_position;

-- 6.4. Tabela TELEGRAM_TASK_TOPICS (mapeamento task ↔ telegram thread)
SELECT 
    'TELEGRAM_TASK_TOPICS' AS tabela,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'telegram_task_topics'
ORDER BY ordinal_position;

-- 6.5. Tabela TASKS
SELECT 
    'TASKS' AS tabela,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'tasks'
ORDER BY ordinal_position;

-- 6.6. Tabela NOTAS (se existir)
SELECT 
    'NOTAS' AS tabela,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'notas'
ORDER BY ordinal_position;

-- 6.7. Tabela ORDENS (se existir)
SELECT 
    'ORDENS' AS tabela,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'ordens'
ORDER BY ordinal_position;

-- ============================================
-- 7. RELACIONAMENTOS ESPECÍFICOS DO CHAT
-- ============================================
-- Verificar como mensagens se relacionam com tarefas/grupos

-- 7.1. FKs da tabela MENSAGENS
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema = 'public'
    AND tc.table_name = 'mensagens'
    AND tc.constraint_type = 'FOREIGN KEY';

-- 7.2. FKs da tabela GRUPOS_CHAT
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema = 'public'
    AND tc.table_name = 'grupos_chat'
    AND tc.constraint_type = 'FOREIGN KEY';

-- 7.3. FKs da tabela TELEGRAM_TASK_TOPICS
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema = 'public'
    AND tc.table_name = 'telegram_task_topics'
    AND tc.constraint_type = 'FOREIGN KEY';

-- ============================================
-- 8. VERIFICAR SE NOTAS/ORDENS TÊM RELAÇÃO COM TASKS
-- ============================================

-- 8.1. FKs da tabela NOTAS (se existir)
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema = 'public'
    AND tc.table_name = 'notas'
    AND tc.constraint_type = 'FOREIGN KEY';

-- 8.2. FKs da tabela ORDENS (se existir)
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema = 'public'
    AND tc.table_name = 'ordens'
    AND tc.constraint_type = 'FOREIGN KEY';

-- ============================================
-- 9. RESUMO: CONTAGEM DE REGISTROS POR TABELA
-- ============================================
-- Útil para entender volume de dados
SELECT 
    schemaname,
    tablename,
    n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ============================================
-- 10. CHECK CONSTRAINTS (para entender regras de negócio)
-- ============================================
SELECT
    tc.table_schema,
    tc.table_name,
    tc.constraint_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public'
    AND tc.constraint_type = 'CHECK'
ORDER BY tc.table_name, tc.constraint_name;
