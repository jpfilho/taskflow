#!/bin/bash
# ============================================
# CORRIGIR SERVIÇO PARA USAR ARQUIVO GENERALIZED
# ============================================

echo "==========================================="
echo "CORRIGINDO SERVIÇO PARA USAR ARQUIVO GENERALIZED"
echo "==========================================="
echo ""

# Verificar se o arquivo generalized existe
if [ ! -f "/root/telegram-webhook/telegram-webhook-server-generalized.js" ]; then
  echo "❌ Arquivo telegram-webhook-server-generalized.js não encontrado!"
  exit 1
fi

echo "1. Parando serviço..."
systemctl stop telegram-webhook

echo ""
echo "2. Fazendo backup do arquivo atual..."
if [ -f "/root/telegram-webhook/telegram-webhook-server.js" ]; then
  cp /root/telegram-webhook/telegram-webhook-server.js /root/telegram-webhook/telegram-webhook-server.js.backup.$(date +%Y%m%d_%H%M%S)
fi

echo ""
echo "3. Copiando arquivo generalized para o arquivo principal..."
cp /root/telegram-webhook/telegram-webhook-server-generalized.js /root/telegram-webhook/telegram-webhook-server.js

echo ""
echo "4. Reiniciando serviço..."
systemctl start telegram-webhook

echo ""
echo "5. Verificando status..."
sleep 2
systemctl status telegram-webhook --no-pager -l | head -20

echo ""
echo "==========================================="
echo "✅ SERVIÇO CORRIGIDO"
echo "==========================================="
echo ""
echo "O serviço agora está usando o arquivo generalized com identificação automática!"
