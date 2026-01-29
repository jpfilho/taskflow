#!/bin/bash
# ============================================
# VERIFICAR TABELA TELEGRAM_COMMUNITIES
# ============================================

echo "==========================================="
echo "VERIFICAR TABELA TELEGRAM_COMMUNITIES"
echo "==========================================="
echo ""

echo "1. Estrutura da tabela:"
docker exec supabase-db psql -U postgres -d postgres -c "\d telegram_communities" 2>&1

echo ""
echo "2. Total de registros:"
docker exec supabase-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM telegram_communities;" 2>&1

echo ""
echo "3. Todos os registros (formato simples):"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  id,
  community_id,
  telegram_chat_id,
  created_at
FROM telegram_communities
ORDER BY created_at;
" 2>&1

echo ""
echo "4. JOIN com comunidades:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.id,
  tc.community_id,
  tc.telegram_chat_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome
FROM telegram_communities tc
LEFT JOIN comunidades c ON c.id = tc.community_id
ORDER BY tc.created_at;
" 2>&1

echo ""
echo "5. Verificando se há registros com o Chat ID -1003721115749:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT COUNT(*) as total
FROM telegram_communities
WHERE telegram_chat_id = -1003721115749;
" 2>&1
