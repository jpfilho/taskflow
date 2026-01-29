#!/bin/bash
# ============================================
# TESTAR ENVIO DIRETO PARA TELEGRAM
# ============================================

BOT_TOKEN="8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
CHAT_ID="-1003721115749"

echo "Testando envio direto para Telegram..."
echo "Chat ID: $CHAT_ID"
echo ""

# Teste 1: Verificar informações do bot
echo "1. Verificando informações do bot..."
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | jq '.'

echo ""
echo ""

# Teste 2: Verificar informações do chat
echo "2. Verificando informações do chat..."
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getChat?chat_id=${CHAT_ID}" | jq '.'

echo ""
echo ""

# Teste 3: Verificar membros do chat
echo "3. Verificando membros do chat..."
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getChatMember?chat_id=${CHAT_ID}&user_id=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | jq -r '.result.id')" | jq '.'

echo ""
echo ""

# Teste 4: Enviar mensagem de teste
echo "4. Enviando mensagem de teste..."
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": ${CHAT_ID},
    \"text\": \"🧪 Teste de envio direto do servidor - $(date)\",
    \"parse_mode\": \"HTML\"
  }")

echo "$RESPONSE" | jq '.'

if echo "$RESPONSE" | jq -e '.ok == true' > /dev/null; then
  echo ""
  echo "✅ Mensagem enviada com sucesso!"
else
  echo ""
  echo "❌ Erro ao enviar mensagem:"
  echo "$RESPONSE" | jq '.description'
fi
