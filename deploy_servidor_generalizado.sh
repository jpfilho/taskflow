#!/bin/bash
# ============================================
# DEPLOY SERVIDOR GENERALIZADO
# ============================================

echo "1. Fazendo backup do servidor atual..."
cp /root/telegram-webhook/telegram-webhook-server.js /root/telegram-webhook/telegram-webhook-server.js.backup.$(date +%Y%m%d_%H%M%S)

echo ""
echo "2. Copiando novo servidor generalizado..."
cp /root/telegram-webhook-server-generalized.js /root/telegram-webhook/telegram-webhook-server.js

echo ""
echo "3. Instalando dependência pg..."
cd /root/telegram-webhook
npm install pg

echo ""
echo "4. Testando sintaxe do Node.js..."
node -c telegram-webhook-server.js
if [ $? -ne 0 ]; then
  echo "❌ Erro de sintaxe no servidor!"
  exit 1
fi

echo ""
echo "5. Reiniciando serviço..."
systemctl restart telegram-webhook

echo ""
echo "6. Verificando status..."
sleep 2
systemctl status telegram-webhook --no-pager | head -15

echo ""
echo "7. Verificando logs recentes..."
journalctl -u telegram-webhook -n 10 --no-pager

echo ""
echo "✅ Deploy concluído!"
