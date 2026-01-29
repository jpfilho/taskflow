#!/bin/bash
# ============================================
# BUSCAR COMUNIDADE POR TELEGRAM CHAT ID
# ============================================

TELEGRAM_CHAT_ID="${1:--1003721115749}"

echo "==========================================="
echo "BUSCAR COMUNIDADE POR TELEGRAM CHAT ID"
echo "==========================================="
echo ""
echo "Telegram Chat ID: $TELEGRAM_CHAT_ID"
echo ""

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.id as vinculacao_id,
  tc.comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  tc.telegram_chat_id,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em,
  (SELECT COUNT(*) FROM telegram_task_topics ttt WHERE ttt.telegram_chat_id = tc.telegram_chat_id) as total_topicos
FROM telegram_communities tc
LEFT JOIN comunidades c ON c.id = tc.comunidade_id
WHERE tc.telegram_chat_id = $TELEGRAM_CHAT_ID
ORDER BY tc.created_at;
" 2>/dev/null

echo ""
echo "==========================================="
echo "TOPICOS CRIADOS NESTE SUPERGRUPO"
echo "==========================================="
echo ""

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  ttt.id,
  ttt.task_id,
  ttt.telegram_topic_id,
  ttt.topic_name,
  gc.tarefa_nome,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  TO_CHAR(ttt.created_at, 'DD/MM/YYYY HH24:MI:SS') as criado_em
FROM telegram_task_topics ttt
LEFT JOIN grupos_chat gc ON gc.tarefa_id = ttt.task_id
LEFT JOIN comunidades c ON c.id = ttt.community_id
WHERE ttt.telegram_chat_id = $TELEGRAM_CHAT_ID
ORDER BY ttt.created_at DESC;
" 2>/dev/null
