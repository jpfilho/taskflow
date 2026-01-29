#!/bin/bash
# ============================================
# VERIFICAR FORUM DETALHADO
# ============================================

TELEGRAM_BOT_TOKEN="8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
TELEGRAM_CHAT_ID="-1003721115749"

echo "==========================================="
echo "VERIFICAR FORUM DETALHADO"
echo "==========================================="
echo ""

echo "1. Verificando informações do chat..."
chat_info=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChat" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": $TELEGRAM_CHAT_ID}")

echo "$chat_info" | jq '.' 2>/dev/null || echo "$chat_info"

echo ""
echo "2. Verificando se é fórum..."
is_forum=$(echo "$chat_info" | jq -r '.result.is_forum' 2>/dev/null)
can_manage_topics=$(echo "$chat_info" | jq -r '.result.permissions.can_manage_topics' 2>/dev/null)

echo "   is_forum: $is_forum"
echo "   can_manage_topics: $can_manage_topics"

echo ""
echo "3. Verificando membros do bot..."
bot_info=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChatMember" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": $TELEGRAM_CHAT_ID,
    \"user_id\": $(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" | jq -r '.result.id')
  }")

echo "$bot_info" | jq '.' 2>/dev/null || echo "$bot_info"

echo ""
echo "4. Tentando criar tópico novamente (após 5 segundos)..."
sleep 5

TOPIC_NAME="Teste Tópico $(date +%H:%M:%S)"
response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/createForumTopic" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": $TELEGRAM_CHAT_ID,
    \"name\": \"$TOPIC_NAME\"
  }")

echo "Resposta:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"

if echo "$response" | grep -q '"ok":true'; then
  echo ""
  echo "✅ Tópico criado com sucesso!"
  topic_id=$(echo "$response" | jq -r '.result.message_thread_id' 2>/dev/null)
  echo "Topic ID: $topic_id"
else
  echo ""
  echo "❌ Ainda não consegue criar tópico."
  echo ""
  echo "Sugestões:"
  echo "1. Remova o bot do grupo e adicione novamente"
  echo "2. Aguarde alguns minutos (cache da API)"
  echo "3. Verifique se o grupo realmente está como Fórum no app do Telegram"
fi
