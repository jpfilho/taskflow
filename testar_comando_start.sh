#!/bin/bash
# ============================================
# TESTAR COMANDO /START DIRETAMENTE
# ============================================

TELEGRAM_BOT_TOKEN="8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"

echo "==========================================="
echo "TESTAR COMANDO /START"
echo "==========================================="
echo ""

echo "Este script vai simular o envio de um comando /start"
echo "Mas primeiro, preciso do seu Telegram User ID"
echo ""

read -p "Digite seu TELEGRAM USER ID (ou deixe vazio para pular): " TELEGRAM_USER_ID

if [ -z "$TELEGRAM_USER_ID" ]; then
  echo ""
  echo "Para descobrir seu Telegram User ID:"
  echo "1. Envie uma mensagem no grupo do Telegram"
  echo "2. Execute: .\obter_telegram_user_id.ps1"
  exit 0
fi

echo ""
echo "Enviando comando /start com payload de teste..."
echo ""

# Simular comando /start com payload
PAYLOAD="link_test_$(date +%s)"

# Nota: Não podemos enviar mensagens diretamente via API do Telegram
# Mas podemos verificar se o webhook está funcionando

echo "Para testar o /start:"
echo "1. Abra o Telegram (app ou web)"
echo "2. Vá até o bot @TaskFlow_chat_bot"
echo "3. Digite manualmente: /start $PAYLOAD"
echo "4. Envie a mensagem"
echo ""
echo "Depois execute: .\ver_logs_start.ps1"
echo ""

echo "Ou use o link direto do Flutter app (já tem o payload correto)"
