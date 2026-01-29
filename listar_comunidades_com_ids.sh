#!/bin/bash
# ============================================
# LISTAR COMUNIDADES COM IDs
# ============================================

echo "==========================================="
echo "COMUNIDADES E SEUS IDs"
echo "==========================================="
echo ""

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id as community_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  CASE 
    WHEN tc.id IS NOT NULL THEN 'SIM'
    ELSE 'NAO'
  END as tem_grupo_telegram,
  tc.telegram_chat_id
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
ORDER BY c.divisao_nome, c.segmento_nome;
" 2>/dev/null
