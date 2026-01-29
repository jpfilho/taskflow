#!/bin/bash

# =========================================
# CONFIGURAR VARIÁVEIS DE AMBIENTE TELEGRAM
# =========================================
# Para Supabase Self-Hosted
# Execute: bash configurar_telegram_env.sh

echo "🔧 Configurando variáveis de ambiente para Telegram..."
echo ""

# =========================================
# 1. CONFIGURAR VARIÁVEIS
# =========================================

SUPABASE_URL="https://srv750497.hstgr.cloud"
TELEGRAM_BOT_TOKEN="8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec"

# IMPORTANTE: Substitua pela sua Service Role Key do Supabase
# Encontre em: Supabase Dashboard → Settings → API → service_role key
SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY_HERE"

if [ "$SUPABASE_SERVICE_ROLE_KEY" = "YOUR_SERVICE_ROLE_KEY_HERE" ]; then
    echo "⚠️  ATENÇÃO: Configure a SUPABASE_SERVICE_ROLE_KEY antes de continuar!"
    echo ""
    echo "1. Abra este arquivo: configurar_telegram_env.sh"
    echo "2. Encontre a linha: SUPABASE_SERVICE_ROLE_KEY=\"YOUR_SERVICE_ROLE_KEY_HERE\""
    echo "3. Substitua YOUR_SERVICE_ROLE_KEY_HERE pela sua service_role key"
    echo "4. Salve o arquivo e execute novamente"
    echo ""
    echo "💡 Onde encontrar a key:"
    echo "   Supabase Dashboard → Settings → API → service_role key (secret)"
    echo ""
    exit 1
fi

# Gerar senha segura para webhook secret
TELEGRAM_WEBHOOK_SECRET="TgWh00k\$ecr3t!2026TaskFlow#$(openssl rand -hex 8)"

echo "📝 Variáveis configuradas:"
echo "   SUPABASE_URL: $SUPABASE_URL"
echo "   TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN:0:20}..."
echo "   TELEGRAM_WEBHOOK_SECRET: ${TELEGRAM_WEBHOOK_SECRET:0:20}..."
echo ""

# =========================================
# 2. CRIAR ARQUIVO .env PARA EDGE FUNCTIONS
# =========================================

# Para telegram-webhook
echo "📄 Criando arquivo .env para telegram-webhook..."
mkdir -p supabase/functions/telegram-webhook
cat > supabase/functions/telegram-webhook/.env << EOF
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_WEBHOOK_SECRET=$TELEGRAM_WEBHOOK_SECRET
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
EOF

# Para telegram-send
echo "📄 Criando arquivo .env para telegram-send..."
mkdir -p supabase/functions/telegram-send
cat > supabase/functions/telegram-send/.env << EOF
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
EOF

echo ""
echo "✅ Arquivos .env criados!"
echo ""

# =========================================
# 3. CRIAR ARQUIVO COM AS VARIÁVEIS (PARA REFERÊNCIA)
# =========================================

echo "📄 Salvando variáveis em telegram_env_vars.txt (para referência)..."
cat > telegram_env_vars.txt << EOF
# =========================================
# VARIÁVEIS DE AMBIENTE - TELEGRAM
# =========================================
# Criado em: $(date)
# 
# IMPORTANTE: Guarde estas variáveis com segurança!
# Você precisará delas para configurar o webhook.

TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_WEBHOOK_SECRET=$TELEGRAM_WEBHOOK_SECRET
SUPABASE_URL=$SUPABASE_URL

# =========================================
# PRÓXIMOS PASSOS:
# =========================================
# 
# 1. Deploy das Edge Functions:
#    supabase functions deploy telegram-webhook
#    supabase functions deploy telegram-send
# 
# 2. Configurar webhook (copie o comando abaixo):
#    curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \\
#      -H "Content-Type: application/json" \\
#      -d "{
#        \"url\": \"$SUPABASE_URL/functions/v1/telegram-webhook\",
#        \"secret_token\": \"$TELEGRAM_WEBHOOK_SECRET\",
#        \"allowed_updates\": [\"message\", \"edited_message\", \"callback_query\"]
#      }"
# 
# 3. Verificar webhook:
#    curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"
EOF

echo ""
echo "✅ Configuração concluída!"
echo ""
echo "📋 RESUMO:"
echo "   ✅ Arquivos .env criados em:"
echo "      - supabase/functions/telegram-webhook/.env"
echo "      - supabase/functions/telegram-send/.env"
echo "   ✅ Variáveis salvas em: telegram_env_vars.txt"
echo ""
echo "🚀 PRÓXIMOS PASSOS:"
echo ""
echo "1️⃣ Deploy das Edge Functions:"
echo "   supabase functions deploy telegram-webhook"
echo "   supabase functions deploy telegram-send"
echo ""
echo "2️⃣ Configurar webhook do Telegram:"
echo "   (comando salvo em telegram_env_vars.txt)"
echo ""
echo "3️⃣ Verificar webhook:"
echo "   curl \"https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo\""
echo ""

# =========================================
# 4. CRIAR SCRIPT PARA CONFIGURAR WEBHOOK
# =========================================

echo "📄 Criando script configurar_webhook.sh..."
cat > configurar_webhook.sh << 'WEBHOOK_SCRIPT'
#!/bin/bash

# Carregar variáveis
source telegram_env_vars.txt 2>/dev/null || {
  echo "❌ Erro: arquivo telegram_env_vars.txt não encontrado"
  echo "Execute primeiro: bash configurar_telegram_env.sh"
  exit 1
}

echo "🔗 Configurando webhook do Telegram..."
echo ""

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{
    \"url\": \"$SUPABASE_URL/functions/v1/telegram-webhook\",
    \"secret_token\": \"$TELEGRAM_WEBHOOK_SECRET\",
    \"allowed_updates\": [\"message\", \"edited_message\", \"callback_query\"]
  }")

echo "📡 Resposta:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

if echo "$RESPONSE" | grep -q '"ok":true'; then
  echo "✅ Webhook configurado com sucesso!"
  echo ""
  echo "🔍 Verificando webhook..."
  curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo" | python3 -m json.tool
else
  echo "❌ Erro ao configurar webhook"
fi
WEBHOOK_SCRIPT

chmod +x configurar_webhook.sh

echo "✅ Script configurar_webhook.sh criado!"
echo ""
echo "💡 DICA: Para configurar o webhook, execute:"
echo "   bash configurar_webhook.sh"
echo ""
