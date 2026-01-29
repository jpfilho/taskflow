-- ============================================
-- INTROSPECÇÃO FOCADA: CHAT + TELEGRAM + TASKS
-- ============================================
-- Script focado nas tabelas críticas para a funcionalidade de tags
-- Execute após o script completo para análise detalhada
-- ============================================

-- ============================================
-- 1. ESTRUTURA COMPLETA DA TABELA MENSAGENS
-- ============================================
SELECT 
    '=== TABELA: MENSAGENS ===' AS info;

SELECT 
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default,
    CASE 
        WHEN column_name IN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'mensagens'
                AND tc.constraint_type = 'PRIMARY KEY'
        ) THEN 'PK'
        WHEN column_name IN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'mensagens'
                AND tc.constraint_type = 'FOREIGN KEY'
        ) THEN 'FK'
        ELSE ''
    END AS key_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'mensagens'
ORDER BY ordinal_position;

-- ============================================
-- 2. ESTRUTURA COMPLETA DA TABELA GRUPOS_CHAT
-- ============================================
SELECT 
    '=== TABELA: GRUPOS_CHAT ===' AS info;

SELECT 
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default,
    CASE 
        WHEN column_name IN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'grupos_chat'
                AND tc.constraint_type = 'PRIMARY KEY'
        ) THEN 'PK'
        WHEN column_name IN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'grupos_chat'
                AND tc.constraint_type = 'FOREIGN KEY'
        ) THEN 'FK'
        ELSE ''
    END AS key_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'grupos_chat'
ORDER BY ordinal_position;

-- ============================================
-- 3. ESTRUTURA COMPLETA DA TABELA TELEGRAM_TASK_TOPICS
-- ============================================
SELECT 
    '=== TABELA: TELEGRAM_TASK_TOPICS ===' AS info;

SELECT 
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default,
    CASE 
        WHEN column_name IN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'telegram_task_topics'
                AND tc.constraint_type = 'PRIMARY KEY'
        ) THEN 'PK'
        WHEN column_name IN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'telegram_task_topics'
                AND tc.constraint_type = 'FOREIGN KEY'
        ) THEN 'FK'
        ELSE ''
    END AS key_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'telegram_task_topics'
ORDER BY ordinal_position;

-- ============================================
-- 4. ESTRUTURA COMPLETA DA TABELA TASKS
-- ============================================
SELECT 
    '=== TABELA: TASKS ===' AS info;

SELECT 
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default,
    CASE 
        WHEN column_name IN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'tasks'
                AND tc.constraint_type = 'PRIMARY KEY'
        ) THEN 'PK'
        WHEN column_name IN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'tasks'
                AND tc.constraint_type = 'FOREIGN KEY'
        ) THEN 'FK'
        ELSE ''
    END AS key_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'tasks'
ORDER BY ordinal_position;

-- ============================================
-- 5. VERIFICAR SE EXISTEM TABELAS NOTAS/ORDENS
-- ============================================
SELECT 
    '=== VERIFICANDO TABELAS NOTAS/ORDENS ===' AS info;

SELECT 
    table_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' 
            AND table_name = t.table_name
        ) THEN 'EXISTE'
        ELSE 'NÃO EXISTE'
    END AS status
FROM information_schema.tables t
WHERE table_schema = 'public'
    AND table_name IN ('notas', 'ordens', 'nota_sap', 'ordem_servico', 'ordens_servico')
ORDER BY table_name;

-- ============================================
-- 6. MAPEAMENTO: COMO MENSAGENS SE LIGAM A TASKS
-- ============================================
SELECT 
    '=== MAPEAMENTO MENSAGENS → TASKS ===' AS info;

-- 6.1. Via grupos_chat
SELECT 
    'MENSAGENS → GRUPOS_CHAT → TASKS' AS caminho,
    m.column_name AS coluna_mensagens,
    gc.column_name AS coluna_grupos_chat,
    t.column_name AS coluna_tasks
FROM information_schema.columns m
CROSS JOIN information_schema.columns gc
CROSS JOIN information_schema.columns t
WHERE m.table_name = 'mensagens'
    AND gc.table_name = 'grupos_chat'
    AND t.table_name = 'tasks'
    AND m.column_name LIKE '%grupo%'
    AND gc.column_name LIKE '%tarefa%'
LIMIT 5;

-- 6.2. Verificar se há campo direto task_id em mensagens
SELECT 
    'VERIFICANDO CAMPOS EM MENSAGENS' AS info,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'mensagens'
    AND (
        column_name LIKE '%task%' 
        OR column_name LIKE '%tarefa%'
        OR column_name LIKE '%nota%'
        OR column_name LIKE '%ordem%'
    );

-- ============================================
-- 7. EXEMPLO DE DADOS REAIS (LIMITADO)
-- ============================================
SELECT 
    '=== EXEMPLO: MENSAGENS (5 primeiras) ===' AS info;

SELECT 
    id,
    grupo_id,
    usuario_nome,
    conteudo,
    tipo,
    created_at
FROM mensagens
ORDER BY created_at DESC
LIMIT 5;

SELECT 
    '=== EXEMPLO: GRUPOS_CHAT (5 primeiros) ===' AS info;

SELECT 
    id,
    tarefa_id,
    tarefa_nome,
    created_at
FROM grupos_chat
ORDER BY created_at DESC
LIMIT 5;

SELECT 
    '=== EXEMPLO: TELEGRAM_TASK_TOPICS (5 primeiros) ===' AS info;

SELECT 
    id,
    task_id,
    grupo_chat_id,
    telegram_chat_id,
    telegram_topic_id,
    topic_name
FROM telegram_task_topics
ORDER BY created_at DESC
LIMIT 5;

-- ============================================
-- 8. VERIFICAR CONSTRAINTS DE CHECK (regras de negócio)
-- ============================================
SELECT 
    '=== CHECK CONSTRAINTS EM MENSAGENS ===' AS info;

SELECT
    constraint_name,
    check_clause
FROM information_schema.check_constraints cc
WHERE constraint_name IN (
    SELECT constraint_name
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
        AND table_name = 'mensagens'
        AND constraint_type = 'CHECK'
);
