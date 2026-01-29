#!/bin/bash
# ============================================
# VERIFICAR TELEGRAM_COMMUNITIES
# ============================================
# Verifica se os Chat IDs foram cadastrados corretamente

echo "==========================================="
echo "VERIFICAR TELEGRAM_COMMUNITIES"
echo "==========================================="
echo ""

echo "1. Total de comunidades:"
docker exec supabase-db psql -U postgres -d postgres -t -A -c "
SELECT COUNT(*) FROM comunidades;
" 2>/dev/null

echo ""
echo "2. Total de comunidades COM Chat ID do Telegram:"
docker exec supabase-db psql -U postgres -d postgres -t -A -c "
SELECT COUNT(DISTINCT tc.community_id)
FROM telegram_communities tc;
" 2>/dev/null

echo ""
echo "3. Total de comunidades SEM Chat ID do Telegram:"
docker exec supabase-db psql -U postgres -d postgres -t -A -c "
SELECT COUNT(*)
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
WHERE tc.id IS NULL;
" 2>/dev/null

echo ""
echo "4. Comunidades COM Chat ID do Telegram:"
echo "----------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id as comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  tc.telegram_chat_id,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em,
  TO_CHAR(tc.updated_at, 'DD/MM/YYYY HH24:MI:SS') as atualizado_em
FROM comunidades c
INNER JOIN telegram_communities tc ON tc.community_id = c.id
ORDER BY tc.created_at DESC;
" 2>/dev/null

echo ""
echo "5. Comunidades SEM Chat ID do Telegram:"
echo "----------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id as comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  c.divisao_id,
  c.segmento_id
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
WHERE tc.id IS NULL
ORDER BY c.divisao_nome, c.segmento_nome;
" 2>/dev/null

echo ""
echo "6. Agrupamento por Chat ID (múltiplas comunidades no mesmo grupo):"
echo "---------------------------------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.telegram_chat_id,
  COUNT(*) as total_comunidades,
  STRING_AGG(c.divisao_nome || ' - ' || c.segmento_nome, ', ' ORDER BY c.divisao_nome, c.segmento_nome) as comunidades
FROM telegram_communities tc
INNER JOIN comunidades c ON c.id = tc.community_id
GROUP BY tc.telegram_chat_id
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
" 2>/dev/null

echo ""
echo "7. Últimas 10 comunidades cadastradas:"
echo "--------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  tc.telegram_chat_id,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
FROM telegram_communities tc
INNER JOIN comunidades c ON c.id = tc.community_id
ORDER BY tc.created_at DESC
LIMIT 10;
" 2>/dev/null
