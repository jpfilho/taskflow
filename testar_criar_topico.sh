#!/bin/bash
# ============================================
# TESTAR CRIAÇÃO DE TÓPICO NO TELEGRAM
# ============================================

TELEGRAM_BOT_TOKEN="8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
TELEGRAM_CHAT_ID="-1003721115749"
TOPIC_NAME="Teste Tópico $(date +%H:%M:%S)"

echo "==========================================="
echo "TESTAR CRIAÇÃO DE TÓPICO"
echo "==========================================="
echo ""

echo "Chat ID: $TELEGRAM_CHAT_ID"
echo "Nome do tópico: $TOPIC_NAME"
echo ""

echo "Enviando requisição para criar tópico..."
response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/createForumTopic" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": $TELEGRAM_CHAT_ID,
    \"name\": \"$TOPIC_NAME\"
  }")

echo "Resposta:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"

echo ""
if echo "$response" | grep -q '"ok":true'; then
  echo "✅ Tópico criado com sucesso!"
  topic_id=$(echo "$response" | jq -r '.result.message_thread_id' 2>/dev/null)
  if [ "$topic_id" != "null" ] && [ -n "$topic_id" ]; then
    echo "Topic ID: $topic_id"
  fi
else
  echo "❌ Erro ao criar tópico!"
  error_desc=$(echo "$response" | jq -r '.description' 2>/dev/null)
  if [ -n "$error_desc" ] && [ "$error_desc" != "null" ]; then
    echo "Erro: $error_desc"
  fi
fi

echo ""
echo "==========================================="
echo "VERIFICANDO INFORMAÇÕES DO CHAT..."
echo "==========================================="
echo ""

echo "Buscando informações do chat..."
chat_info=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChat" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": $TELEGRAM_CHAT_ID}")

echo "Informações do chat:"
echo "$chat_info" | jq '.' 2>/dev/null || echo "$chat_info"

echo ""
is_forum=$(echo "$chat_info" | jq -r '.is_forum' 2>/dev/null)
if [ "$is_forum" = "true" ]; then
  echo "✅ Chat é um Fórum (Topics habilitado)"
else
  echo "❌ Chat NÃO é um Fórum! Precisa converter para Fórum."
fi
