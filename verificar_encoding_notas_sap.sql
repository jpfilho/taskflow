-- ============================================
-- SQL PARA VERIFICAR E CORRIGIR ENCODING DA TABELA NOTAS_SAP
-- ============================================
-- Execute este script no SQL Editor do Supabase Dashboard
-- https://srv750497.hstgr.cloud/project/default/sql/new

-- Verificar encoding atual da tabela
SELECT 
    table_name,
    column_name,
    data_type,
    character_set_name,
    collation_name
FROM information_schema.columns
WHERE table_name = 'notas_sap'
    AND data_type LIKE '%char%'
ORDER BY ordinal_position;

-- Verificar encoding do banco de dados
SHOW server_encoding;
SHOW client_encoding;

-- Verificar algumas notas com caracteres especiais
SELECT 
    nota,
    descricao,
    text_prioridade,
    denominacao_executor,
    encode(descricao::bytea, 'hex') as descricao_hex,
    encode(text_prioridade::bytea, 'hex') as prioridade_hex
FROM notas_sap
WHERE descricao LIKE '%ão%' 
   OR descricao LIKE '%ção%'
   OR text_prioridade LIKE '%édia%'
LIMIT 10;

-- IMPORTANTE: Se o encoding do banco não for UTF-8, pode ser necessário:
-- 1. Alterar o encoding da coluna (se possível)
-- 2. Ou garantir que os dados sejam enviados corretamente do cliente

-- Verificar se há caracteres inválidos
SELECT 
    nota,
    descricao,
    CASE 
        WHEN descricao ~ '[^\x00-\x7F]' THEN 'Contém caracteres não-ASCII'
        ELSE 'Apenas ASCII'
    END as encoding_status
FROM notas_sap
LIMIT 20;

