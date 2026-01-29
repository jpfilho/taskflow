#!/bin/bash
# ============================================
# LISTAR COMUNIDADES E SUPERGRUPOS
# ============================================

echo "==========================================="
echo "COMUNIDADES E SUPERGRUPOS TELEGRAM"
echo "==========================================="
echo ""

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  c.id as comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  tc.telegram_chat_id as supergrupo_telegram_id,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em,
  (SELECT COUNT(*) FROM telegram_task_topics ttt WHERE ttt.community_id = c.id) as total_topicos_criados
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
ORDER BY c.divisao_nome, c.segmento_nome;
" 2>/dev/null

echo ""
echo "==========================================="
echo "RESUMO"
echo "==========================================="
echo ""

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  COUNT(DISTINCT c.id) as total_comunidades,
  COUNT(DISTINCT tc.id) as comunidades_com_supergrupo,
  COUNT(DISTINCT tc.telegram_chat_id) as supergrupos_unicos,
  COUNT(DISTINCT ttt.id) as total_topicos_criados
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
LEFT JOIN telegram_task_topics ttt ON ttt.community_id = c.id;
" 2>/dev/null
