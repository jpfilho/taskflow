#!/bin/bash
# ============================================
# DIAGNOSTICAR CRIAÇÃO DE TÓPICOS
# ============================================

echo "==========================================="
echo "DIAGNOSTICAR CRIAÇÃO DE TÓPICOS"
echo "==========================================="
echo ""

# Variáveis
SUPABASE_URL="http://127.0.0.1:8000"
SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw"
TELEGRAM_BOT_TOKEN="8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
GRUPO_ID="369377cf-3678-43e2-8314-f4accf58575f"

echo "1. Buscando informações do grupo..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  gc.id as grupo_id,
  gc.tarefa_id,
  gc.tarefa_nome,
  gc.comunidade_id,
  c.nome as comunidade_nome
FROM grupos_chat gc
LEFT JOIN comunidades c ON c.id = gc.comunidade_id
WHERE gc.id = '$GRUPO_ID';
" 2>/dev/null

echo ""
echo "2. Verificando se comunidade tem supergrupo configurado..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  tc.id,
  tc.comunidade_id,
  tc.telegram_chat_id,
  c.nome as comunidade_nome
FROM telegram_communities tc
LEFT JOIN comunidades c ON c.id = tc.comunidade_id
WHERE tc.comunidade_id = (
  SELECT comunidade_id FROM grupos_chat WHERE id = '$GRUPO_ID'
);
" 2>/dev/null

echo ""
echo "3. Verificando se já existe tópico para esta tarefa..."
psql -h 127.0.0.1 -U postgres -d postgres -c "
SELECT 
  ttt.id,
  ttt.task_id,
  ttt.telegram_chat_id,
  ttt.telegram_topic_id,
  ttt.topic_name,
  gc.tarefa_nome
FROM telegram_task_topics ttt
LEFT JOIN grupos_chat gc ON gc.tarefa_id = ttt.task_id
WHERE ttt.task_id = (
  SELECT tarefa_id FROM grupos_chat WHERE id = '$GRUPO_ID'
);
" 2>/dev/null

echo ""
echo "4. Verificando logs recentes do servidor..."
journalctl -u telegram-webhook -n 30 --no-pager | grep -E "(ensureTaskTopic|Topic not available|telegram_chat_id|comunidade)" || echo "Nenhum log relevante encontrado"

echo ""
echo "✅ Diagnóstico concluído!"
