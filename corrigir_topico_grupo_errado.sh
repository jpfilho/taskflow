#!/bin/bash
# ============================================
# CORRIGIR TÓPICO APONTANDO PARA GRUPO ERRADO
# ============================================

if [ -z "$1" ]; then
  echo "Uso: $0 <task_id>"
  echo ""
  echo "Este script corrige o tópico de uma tarefa que está apontando para o grupo errado"
  echo ""
  echo "Exemplo:"
  echo "  $0 123e4567-e89b-12d3-a456-426614174000"
  echo ""
  echo "Para encontrar o task_id, use o grupo_chat_id da mensagem:"
  echo "  docker exec supabase-db psql -U postgres -d postgres -c \"SELECT tarefa_id FROM grupos_chat WHERE id = 'GRUPO_CHAT_ID';\""
  exit 1
fi

TASK_ID="$1"

echo "==========================================="
echo "CORRIGIR TÓPICO PARA GRUPO CORRETO"
echo "==========================================="
echo ""

echo "1. Verificando tarefa e comunidade..."
echo "-------------------------------------------"
TASK_INFO=$(docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT 
  gc.tarefa_id,
  gc.comunidade_id,
  c.divisao_nome || ' - ' || c.segmento_nome as comunidade_nome
FROM grupos_chat gc
JOIN comunidades c ON c.id = gc.comunidade_id
WHERE gc.tarefa_id = '$TASK_ID';
" 2>/dev/null)

if [ -z "$TASK_INFO" ]; then
  echo "❌ Tarefa não encontrada!"
  exit 1
fi

IFS='|' read -r TID CID COMUNIDADE <<< "$TASK_INFO"
echo "✅ Tarefa encontrada:"
echo "   Comunidade: $COMUNIDADE"
echo ""

echo "2. Verificando grupo Telegram correto para esta comunidade..."
echo "-------------------------------------------"
GRUPO_CORRETO=$(docker exec supabase-db psql -U postgres -d postgres -t -c "
SELECT telegram_chat_id
FROM telegram_communities
WHERE community_id = '$CID'
LIMIT 1;
" 2>/dev/null | xargs)

if [ -z "$GRUPO_CORRETO" ]; then
  echo "❌ Comunidade não tem grupo Telegram configurado!"
  echo ""
  echo "Configure o grupo primeiro usando:"
  echo "  .\cadastrar_grupo_comunidade.ps1 -CommunityId $CID -TelegramChatId <CHAT_ID>"
  exit 1
fi

echo "✅ Grupo Telegram correto: $GRUPO_CORRETO"
echo ""

echo "3. Verificando tópico atual..."
echo "-------------------------------------------"
TOPICO_ATUAL=$(docker exec supabase-db psql -U postgres -d postgres -t -A -F'|' -c "
SELECT 
  id,
  telegram_chat_id,
  telegram_topic_id,
  topic_name
FROM telegram_task_topics
WHERE task_id = '$TASK_ID';
" 2>/dev/null)

if [ -z "$TOPICO_ATUAL" ]; then
  echo "⚠️ Tópico não encontrado. Será criado automaticamente na próxima mensagem."
  exit 0
fi

IFS='|' read -r TID_TOPICO CHAT_ATUAL TOPIC_ID TOPIC_NAME <<< "$TOPICO_ATUAL"
echo "Tópico atual:"
echo "  Chat ID: $CHAT_ATUAL"
echo "  Topic ID: $TOPIC_ID"
echo "  Nome: $TOPIC_NAME"
echo ""

if [ "$CHAT_ATUAL" = "$GRUPO_CORRETO" ]; then
  echo "✅ Tópico já está apontando para o grupo correto!"
  exit 0
fi

echo "⚠️ Tópico está no grupo ERRADO!"
echo "   Grupo atual: $CHAT_ATUAL"
echo "   Grupo correto: $GRUPO_CORRETO"
echo ""
read -p "Deseja deletar o tópico errado e criar um novo no grupo correto? (s/N): " CONFIRM

if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
  echo "Operação cancelada."
  exit 0
fi

echo ""
echo "4. Deletando tópico do grupo errado..."
echo "-------------------------------------------"
docker exec supabase-db psql -U postgres -d postgres -c "
DELETE FROM telegram_task_topics
WHERE task_id = '$TASK_ID';
" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "✅ Tópico deletado!"
  echo ""
  echo "Na próxima mensagem enviada desta tarefa, um novo tópico será criado no grupo correto ($GRUPO_CORRETO)"
else
  echo "❌ Erro ao deletar tópico"
  exit 1
fi
