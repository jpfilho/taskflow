#!/bin/bash
# ============================================
# VERIFICAR COMUNIDADES - DIRETO
# ============================================

echo "==========================================="
echo "VERIFICAR COMUNIDADES"
echo "==========================================="
echo ""

echo "1. Total de comunidades:"
docker exec supabase-db psql -U postgres -d postgres -t -A -c "SELECT COUNT(*) FROM comunidades;" 2>/dev/null

echo ""
echo "2. Total de comunidades COM supergrupo:"
docker exec supabase-db psql -U postgres -d postgres -t -A -c "
SELECT COUNT(*) 
FROM telegram_communities;
" 2>/dev/null

echo ""
echo "3. Listando TODAS as comunidades e status:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  CASE 
    WHEN tc.id IS NOT NULL THEN 'SIM'
    ELSE 'NAO'
  END as tem_supergrupo,
  tc.telegram_chat_id
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
ORDER BY c.divisao_nome, c.segmento_nome;
" 2>/dev/null
