#!/bin/bash
# ============================================
# VERIFICAR CRIACAO DE TOPICO AUTOMATICA
# ============================================

echo "==========================================="
echo "VERIFICAR CRIACAO DE TOPICO AUTOMATICA"
echo "==========================================="
echo ""

echo "1. Verificando logs recentes do /send-message..."
journalctl -u telegram-webhook -n 100 --no-pager | grep -E "(send-message|ensureTaskTopic|Criando tópico|Topic not available|Task not found)" | tail -20

echo ""
echo "2. Verificando comunidades cadastradas..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  tc.id,
  tc.comunidade_id,
  c.nome as comunidade_nome,
  tc.telegram_chat_id,
  tc.created_at
FROM telegram_communities tc
LEFT JOIN comunidades c ON c.id = tc.comunidade_id
ORDER BY tc.created_at DESC;
" 2>/dev/null

echo ""
echo "3. Verificando tópicos criados..."
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT 
  ttt.id,
  ttt.task_id,
  ttt.telegram_chat_id,
  ttt.telegram_topic_id,
  ttt.topic_name,
  gc.tarefa_nome,
  c.nome as comunidade_nome
FROM telegram_task_topics ttt
LEFT JOIN grupos_chat gc ON gc.tarefa_id = ttt.task_id
LEFT JOIN comunidades c ON c.id = ttt.community_id
ORDER BY ttt.created_at DESC
LIMIT 10;
" 2>/dev/null
