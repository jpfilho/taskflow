-- ============================================
-- QUERIES PARA BUSCAR NOTAS E ORDENS
-- ============================================
-- Queries auxiliares para implementação da funcionalidade de tags
-- ============================================

-- ============================================
-- 1. BUSCAR NOTAS DE UMA TAREFA
-- ============================================
-- Retorna todas as notas vinculadas a uma tarefa
-- com contagem de mensagens vinculadas a cada nota

SELECT 
    ns.id AS nota_id,
    ns.nota AS nota_numero,  -- Campo 'nota' é o identificador único (VARCHAR(50))
    ns.descricao AS nota_descricao,
    COUNT(DISTINCT m.id) AS total_mensagens,
    MAX(m.created_at) AS ultima_mensagem_at
FROM tasks_notas_sap tns
JOIN notas_sap ns ON ns.id = tns.nota_sap_id
LEFT JOIN mensagens m ON m.ref_type = 'NOTA' 
    AND m.ref_id = ns.id 
    AND m.deleted_at IS NULL
WHERE tns.task_id = '<task_id>'  -- Substituir pelo UUID da tarefa
GROUP BY ns.id, ns.nota, ns.descricao
ORDER BY ns.nota;

-- ============================================
-- 2. BUSCAR ORDENS DE UMA TAREFA
-- ============================================
-- Retorna todas as ordens vinculadas a uma tarefa
-- com contagem de mensagens vinculadas a cada ordem

SELECT 
    o.id AS ordem_id,
    o.ordem AS ordem_numero,  -- Campo 'ordem' é o identificador único (TEXT)
    o.texto_breve AS ordem_descricao,  -- Usando texto_breve como descrição
    COUNT(DISTINCT m.id) AS total_mensagens,
    MAX(m.created_at) AS ultima_mensagem_at
FROM tasks_ordens to_rel
JOIN ordens o ON o.id = to_rel.ordem_id
LEFT JOIN mensagens m ON m.ref_type = 'ORDEM' 
    AND m.ref_id = o.id 
    AND m.deleted_at IS NULL
WHERE to_rel.task_id = '<task_id>'  -- Substituir pelo UUID da tarefa
GROUP BY o.id, o.ordem, o.texto_breve
ORDER BY o.ordem;

-- ============================================
-- 3. BUSCAR MENSAGENS DE UMA NOTA
-- ============================================
-- Retorna todas as mensagens vinculadas a uma nota específica

SELECT 
    m.id,
    m.conteudo,
    m.usuario_nome,
    m.usuario_id,
    m.created_at,
    m.ref_label,
    m.tipo,
    m.arquivo_url,
    gc.tarefa_id,
    gc.tarefa_nome
FROM mensagens m
JOIN grupos_chat gc ON gc.id = m.grupo_id
WHERE m.ref_type = 'NOTA' 
    AND m.ref_id = '<nota_sap_id>'  -- Substituir pelo UUID da nota
    AND m.deleted_at IS NULL
ORDER BY m.created_at ASC;

-- ============================================
-- 4. BUSCAR MENSAGENS DE UMA ORDEM
-- ============================================
-- Retorna todas as mensagens vinculadas a uma ordem específica

SELECT 
    m.id,
    m.conteudo,
    m.usuario_nome,
    m.usuario_id,
    m.created_at,
    m.ref_label,
    m.tipo,
    m.arquivo_url,
    gc.tarefa_id,
    gc.tarefa_nome
FROM mensagens m
JOIN grupos_chat gc ON gc.id = m.grupo_id
WHERE m.ref_type = 'ORDEM' 
    AND m.ref_id = '<ordem_id>'  -- Substituir pelo UUID da ordem
    AND m.deleted_at IS NULL
ORDER BY m.created_at ASC;

-- ============================================
-- 5. BUSCAR MENSAGENS DE UMA TAREFA POR TIPO
-- ============================================
-- Retorna mensagens de uma tarefa, agrupadas por tipo de referência
-- Útil para dashboard/estatísticas

SELECT 
    COALESCE(m.ref_type, 'GERAL') AS ref_type,
    m.ref_id,
    m.ref_label,
    COUNT(*) AS quantidade_mensagens,
    COUNT(DISTINCT m.usuario_id) AS usuarios_unicos,
    MIN(m.created_at) AS primeira_mensagem,
    MAX(m.created_at) AS ultima_mensagem
FROM mensagens m
JOIN grupos_chat gc ON gc.id = m.grupo_id
WHERE gc.tarefa_id = '<task_id>'  -- Substituir pelo UUID da tarefa
    AND m.deleted_at IS NULL
GROUP BY m.ref_type, m.ref_id, m.ref_label
ORDER BY 
    CASE m.ref_type
        WHEN 'NOTA' THEN 1
        WHEN 'ORDEM' THEN 2
        WHEN 'GERAL' THEN 3
        ELSE 4
    END,
    m.ref_label;

-- ============================================
-- 6. BUSCAR TODAS AS MENSAGENS DE UMA TAREFA COM TAGS
-- ============================================
-- Retorna todas as mensagens de uma tarefa com informações de tag
-- Útil para exibição no chat com filtros

SELECT 
    m.id,
    m.conteudo,
    m.usuario_nome,
    m.usuario_id,
    m.created_at,
    m.ref_type,
    m.ref_id,
    m.ref_label,
    m.tipo,
    m.arquivo_url,
    m.mensagem_respondida_id,
    -- Informações da nota (se aplicável)
    CASE 
        WHEN m.ref_type = 'NOTA' THEN ns.nota
        ELSE NULL
    END AS nota_numero,
    -- Informações da ordem (se aplicável)
    CASE 
        WHEN m.ref_type = 'ORDEM' THEN o.ordem
        ELSE NULL
    END AS ordem_numero
FROM mensagens m
JOIN grupos_chat gc ON gc.id = m.grupo_id
LEFT JOIN notas_sap ns ON ns.id = m.ref_id AND m.ref_type = 'NOTA'
LEFT JOIN ordens o ON o.id = m.ref_id AND m.ref_type = 'ORDEM'
WHERE gc.tarefa_id = '<task_id>'  -- Substituir pelo UUID da tarefa
    AND m.deleted_at IS NULL
ORDER BY m.created_at ASC;

-- ============================================
-- 7. ESTATÍSTICAS DE TAGS POR TAREFA
-- ============================================
-- Retorna estatísticas de uso de tags em uma tarefa

SELECT 
    gc.tarefa_id,
    gc.tarefa_nome,
    COUNT(*) AS total_mensagens,
    COUNT(CASE WHEN m.ref_type = 'GERAL' THEN 1 END) AS mensagens_gerais,
    COUNT(CASE WHEN m.ref_type = 'NOTA' THEN 1 END) AS mensagens_notas,
    COUNT(CASE WHEN m.ref_type = 'ORDEM' THEN 1 END) AS mensagens_ordens,
    COUNT(DISTINCT CASE WHEN m.ref_type = 'NOTA' THEN m.ref_id END) AS notas_unicas,
    COUNT(DISTINCT CASE WHEN m.ref_type = 'ORDEM' THEN m.ref_id END) AS ordens_unicas
FROM grupos_chat gc
LEFT JOIN mensagens m ON m.grupo_id = gc.id AND m.deleted_at IS NULL
WHERE gc.tarefa_id = '<task_id>'  -- Substituir pelo UUID da tarefa
GROUP BY gc.tarefa_id, gc.tarefa_nome;

-- ============================================
-- 8. VALIDAR INTEGRIDADE DE TAGS
-- ============================================
-- Verifica se há mensagens com tags inválidas
-- (ref_id que não existe em notas_sap ou ordens)

-- 8.1. Mensagens com ref_type='NOTA' mas ref_id não existe em notas_sap
SELECT 
    m.id AS mensagem_id,
    m.ref_id,
    m.ref_label,
    m.created_at,
    'NOTA não encontrada' AS erro
FROM mensagens m
WHERE m.ref_type = 'NOTA'
    AND m.ref_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM notas_sap ns WHERE ns.id = m.ref_id
    );

-- 8.2. Mensagens com ref_type='ORDEM' mas ref_id não existe em ordens
SELECT 
    m.id AS mensagem_id,
    m.ref_id,
    m.ref_label,
    m.created_at,
    'ORDEM não encontrada' AS erro
FROM mensagens m
WHERE m.ref_type = 'ORDEM'
    AND m.ref_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM ordens o WHERE o.id = m.ref_id
    );

-- 8.3. Mensagens com ref_type='GERAL' mas ref_id preenchido (inconsistência)
SELECT 
    m.id AS mensagem_id,
    m.ref_type,
    m.ref_id,
    m.ref_label,
    m.created_at,
    'ref_id não deveria estar preenchido para GERAL' AS erro
FROM mensagens m
WHERE m.ref_type = 'GERAL'
    AND m.ref_id IS NOT NULL;

-- 8.4. Mensagens com ref_type IN ('NOTA', 'ORDEM') mas ref_id NULL (inconsistência)
SELECT 
    m.id AS mensagem_id,
    m.ref_type,
    m.ref_id,
    m.ref_label,
    m.created_at,
    'ref_id é obrigatório para NOTA/ORDEM' AS erro
FROM mensagens m
WHERE m.ref_type IN ('NOTA', 'ORDEM')
    AND m.ref_id IS NULL;
