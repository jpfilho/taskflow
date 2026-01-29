-- ============================================
-- VALIDAÇÃO: ESTRUTURA DE NOTAS E ORDENS
-- ============================================
-- Execute este script para validar os campos antes de implementar
-- ============================================

-- ============================================
-- 1. VERIFICAR ESTRUTURA DE notas_sap
-- ============================================
SELECT 
    '=== ESTRUTURA: notas_sap ===' AS info;

SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'notas_sap'
    AND column_name IN ('id', 'nota', 'numero', 'descricao')
ORDER BY ordinal_position;

-- Verificar se campo 'nota' existe e é UNIQUE
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'notas_sap'
                AND kcu.column_name = 'nota'
                AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
        ) THEN '✅ Campo "nota" existe e é UNIQUE'
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'notas_sap'
                AND column_name = 'nota'
        ) THEN '⚠️ Campo "nota" existe mas NÃO é UNIQUE'
        ELSE '❌ Campo "nota" NÃO existe'
    END AS status_nota;

-- ============================================
-- 2. VERIFICAR ESTRUTURA DE ordens
-- ============================================
SELECT 
    '=== ESTRUTURA: ordens ===' AS info;

SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'ordens'
    AND column_name IN ('id', 'ordem', 'numero', 'texto_breve', 'descricao')
ORDER BY ordinal_position;

-- Verificar se campo 'ordem' existe e é UNIQUE
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
                AND tc.table_name = 'ordens'
                AND kcu.column_name = 'ordem'
                AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
        ) THEN '✅ Campo "ordem" existe e é UNIQUE'
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'ordens'
                AND column_name = 'ordem'
        ) THEN '⚠️ Campo "ordem" existe mas NÃO é UNIQUE'
        ELSE '❌ Campo "ordem" NÃO existe'
    END AS status_ordem;

-- ============================================
-- 3. TESTAR BUSCA DE NOTAS
-- ============================================
SELECT 
    '=== TESTE: Buscar 5 notas ===' AS info;

SELECT 
    id,
    nota,  -- Campo identificador
    descricao,
    status_sistema,
    local_instalacao
FROM notas_sap
ORDER BY nota
LIMIT 5;

-- ============================================
-- 4. TESTAR BUSCA DE ORDENS
-- ============================================
SELECT 
    '=== TESTE: Buscar 5 ordens ===' AS info;

SELECT 
    id,
    ordem,  -- Campo identificador
    texto_breve,
    status_sistema,
    local_instalacao
FROM ordens
ORDER BY ordem
LIMIT 5;

-- ============================================
-- 5. TESTAR RELACIONAMENTOS
-- ============================================
SELECT 
    '=== TESTE: Notas vinculadas a uma tarefa ===' AS info;

-- Substituir '<task_id>' por um ID real de tarefa
SELECT 
    tns.task_id,
    ns.id AS nota_id,
    ns.nota AS nota_numero,
    ns.descricao
FROM tasks_notas_sap tns
JOIN notas_sap ns ON ns.id = tns.nota_sap_id
WHERE tns.task_id IN (
    SELECT id FROM tasks LIMIT 1  -- Pegar primeira tarefa como exemplo
)
ORDER BY ns.nota
LIMIT 5;

SELECT 
    '=== TESTE: Ordens vinculadas a uma tarefa ===' AS info;

-- Substituir '<task_id>' por um ID real de tarefa
SELECT 
    to_rel.task_id,
    o.id AS ordem_id,
    o.ordem AS ordem_numero,
    o.texto_breve
FROM tasks_ordens to_rel
JOIN ordens o ON o.id = to_rel.ordem_id
WHERE to_rel.task_id IN (
    SELECT id FROM tasks LIMIT 1  -- Pegar primeira tarefa como exemplo
)
ORDER BY o.ordem
LIMIT 5;

-- ============================================
-- 6. VERIFICAR SE grupos_chat TEM tarefa_id
-- ============================================
SELECT 
    '=== VERIFICAR: grupos_chat.tarefa_id ===' AS info;

SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'grupos_chat'
    AND column_name LIKE '%tarefa%'
ORDER BY ordinal_position;

-- Verificar FK de grupos_chat para tasks
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public'
    AND tc.table_name = 'grupos_chat'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name LIKE '%tarefa%';

-- ============================================
-- 7. RESUMO FINAL
-- ============================================
SELECT 
    '=== RESUMO: Campos para Implementação ===' AS info;

SELECT 
    'notas_sap' AS tabela,
    'nota' AS campo_identificador,
    'VARCHAR(50)' AS tipo_esperado,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'notas_sap'
                AND column_name = 'nota'
        ) THEN '✅ Existe'
        ELSE '❌ NÃO existe'
    END AS status
UNION ALL
SELECT 
    'ordens' AS tabela,
    'ordem' AS campo_identificador,
    'TEXT' AS tipo_esperado,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'ordens'
                AND column_name = 'ordem'
        ) THEN '✅ Existe'
        ELSE '❌ NÃO existe'
    END AS status
UNION ALL
SELECT 
    'grupos_chat' AS tabela,
    'tarefa_id' AS campo_identificador,
    'UUID' AS tipo_esperado,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
                AND table_name = 'grupos_chat'
                AND column_name = 'tarefa_id'
        ) THEN '✅ Existe'
        ELSE '❌ NÃO existe'
    END AS status;
