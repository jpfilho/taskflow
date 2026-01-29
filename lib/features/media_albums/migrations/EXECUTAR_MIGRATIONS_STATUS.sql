-- ============================================
-- MIGRAÇÕES: Status de Álbuns - Execução Completa
-- ============================================
-- Execute estas migrations na ordem apresentada
-- ============================================

-- ============================================
-- 1. CRIAR TABELA status_albums
-- ============================================
-- Execute primeiro: create_status_albums_table.sql
-- ============================================

-- ============================================
-- 2. ADICIONAR status_album_id EM media_images
-- ============================================
-- Execute depois: ADICIONAR_STATUS_ALBUM_ID.sql
-- ============================================

-- ============================================
-- VERIFICAÇÃO PÓS-MIGRAÇÃO
-- ============================================

-- Verificar se a tabela status_albums foi criada
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'status_albums'
ORDER BY ordinal_position;

-- Verificar se a coluna status_album_id foi adicionada
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'media_images'
    AND column_name = 'status_album_id';

-- Verificar status padrão criados
SELECT id, nome, cor_fundo, cor_texto, ativo, ordem
FROM status_albums
ORDER BY ordem, nome;

-- Verificar imagens com status vinculado
SELECT 
    mi.id,
    mi.title,
    mi.status as status_antigo,
    mi.status_album_id,
    sa.nome as status_nome,
    sa.cor_fundo,
    sa.cor_texto
FROM media_images mi
LEFT JOIN status_albums sa ON mi.status_album_id = sa.id
ORDER BY mi.created_at DESC
LIMIT 10;
