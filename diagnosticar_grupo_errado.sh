#!/bin/bash
# ============================================
# DIAGNOSTICAR POR QUE MENSAGEM FOI PARA GRUPO ERRADO
# ============================================

echo "==========================================="
echo "DIAGNOSTICAR GRUPO ERRADO"
echo "==========================================="
echo ""

echo "1. Verificando qual grupo foi usado na última mensagem:"
echo "-------------------------------------------"
journalctl -u telegram-webhook -n 100 --no-pager | grep -E "(send-message|ensureTaskTopic|telegram_chat_id|task_id)" | tail -20
echo ""

echo "2. Verificando grupos cadastrados:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.id,
  tc.telegram_chat_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade,
  TO_CHAR(tc.created_at, 'DD/MM/YYYY HH24:MI:SS') as cadastrado_em
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.comunidade_id
ORDER BY tc.created_at DESC;
" 2>/dev/null

echo ""
echo "3. Verificando tarefa da mensagem enviada:"
echo "-------------------------------------------"
echo "Mensagem ID: c28aaf89-203b-4ec5-b29d-3e2943059a55"
echo "Grupo ID: 0b11a193-d4b3-4562-b3df-8e4d2a4ca871"
echo ""

docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  gc.id as grupo_chat_id,
  gc.tarefa_id,
  gc.tarefa_nome,
  gc.comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome
FROM grupos_chat gc
JOIN comunidades c ON c.id = gc.comunidade_id
WHERE gc.id = '0b11a193-d4b3-4562-b3df-8e4d2a4ca871';
" 2>/dev/null

echo ""
echo "4. Verificando qual grupo Telegram deveria ser usado:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  gc.tarefa_id,
  gc.comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome,
  tc.telegram_chat_id as grupo_telegram_usado
FROM grupos_chat gc
JOIN comunidades c ON c.id = gc.comunidade_id
LEFT JOIN telegram_communities tc ON tc.comunidade_id = c.id
WHERE gc.id = '0b11a193-d4b3-4562-b3df-8e4d2a4ca871';
" 2>/dev/null

echo ""
echo "5. Verificando tópicos criados para esta tarefa:"
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  ttt.id,
  ttt.task_id,
  ttt.telegram_chat_id,
  ttt.telegram_topic_id,
  ttt.topic_name,
  TO_CHAR(ttt.created_at, 'DD/MM/YYYY HH24:MI:SS') as criado_em
FROM telegram_task_topics ttt
JOIN grupos_chat gc ON gc.tarefa_id = ttt.task_id
WHERE gc.id = '0b11a193-d4b3-4562-b3df-8e4d2a4ca871';
" 2>/dev/null
