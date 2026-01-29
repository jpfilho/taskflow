#!/bin/bash
# ============================================
# VERIFICAR CONFIGURACAO DO WEBHOOK
# ============================================

TELEGRAM_BOT_TOKEN="8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"

echo "==========================================="
echo "VERIFICAR CONFIGURACAO DO WEBHOOK"
echo "==========================================="
echo ""

echo "1. Verificando informações do webhook..."
webhook_info=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo")

echo "$webhook_info" | jq '.' 2>/dev/null || echo "$webhook_info"

echo ""
echo "2. Verificando se webhook está ativo..."
is_active=$(echo "$webhook_info" | jq -r '.result.url' 2>/dev/null)

if [ -n "$is_active" ] && [ "$is_active" != "null" ]; then
  echo "   ✅ Webhook configurado: $is_active"
  
  # Verificar allowed_updates
  allowed_updates=$(echo "$webhook_info" | jq -r '.result.allowed_updates[]' 2>/dev/null)
  echo ""
  echo "   Updates permitidos:"
  if [ -z "$allowed_updates" ]; then
    echo "   ⚠️  Nenhum update específico configurado (recebe todos)"
  else
    echo "$allowed_updates" | while read update; do
      echo "      - $update"
    done
  fi
  
  # Verificar se 'message' está nos allowed_updates
  if echo "$allowed_updates" | grep -q "message"; then
    echo ""
    echo "   ✅ Mensagens privadas devem ser recebidas"
  else
    echo ""
    echo "   ⚠️  'message' não está nos allowed_updates"
    echo "   Isso pode impedir recebimento de mensagens privadas!"
  fi
else
  echo "   ❌ Webhook não configurado!"
fi

echo ""
echo "3. Verificando pendências..."
pending_count=$(echo "$webhook_info" | jq -r '.result.pending_update_count' 2>/dev/null)
if [ "$pending_count" != "null" ] && [ "$pending_count" -gt 0 ]; then
  echo "   ⚠️  Há $pending_count updates pendentes!"
  echo "   Execute: curl -X POST \"https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates\""
else
  echo "   ✅ Nenhuma pendência"
fi
