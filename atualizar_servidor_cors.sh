#!/bin/bash
# ============================================
# ATUALIZAR SERVIDOR COM CORS
# ============================================

echo "1. Parando serviço..."
systemctl stop telegram-webhook

echo ""
echo "2. Fazendo backup do servidor atual..."
cp /root/telegram-webhook/telegram-webhook-server.js /root/telegram-webhook/telegram-webhook-server.js.backup.$(date +%Y%m%d_%H%M%S)

echo ""
echo "3. Copiando novo arquivo..."
# O arquivo já deve estar no servidor, mas vamos garantir
if [ -f "/root/telegram-webhook-server.js" ]; then
  cp /root/telegram-webhook-server.js /root/telegram-webhook/telegram-webhook-server.js
  echo "✅ Arquivo copiado"
else
  echo "⚠️ Arquivo não encontrado em /root/, usando o que está em /root/telegram-webhook/"
fi

echo ""
echo "4. Reiniciando serviço..."
systemctl start telegram-webhook

echo ""
echo "5. Verificando status..."
sleep 2
systemctl status telegram-webhook --no-pager | head -10

echo ""
echo "6. Verificando logs recentes..."
journalctl -u telegram-webhook -n 5 --no-pager

echo ""
echo "✅ Servidor atualizado com suporte CORS!"
