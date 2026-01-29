#!/bin/bash
# ============================================
# ATUALIZAR SERVIDOR COM AUTO-CADASTRO DE GRUPOS
# ============================================

echo "==========================================="
echo "ATUALIZANDO SERVIDOR TELEGRAM"
echo "==========================================="
echo ""

cd /root/telegram-webhook || exit 1

echo "1. Fazendo backup do servidor atual..."
cp telegram-webhook-server-generalized.js telegram-webhook-server-generalized.js.backup

echo "2. Copiando novo servidor..."
# Verificar se o arquivo generalized existe
if [ -f "/root/telegram-webhook-server-generalized.js" ]; then
  cp /root/telegram-webhook-server-generalized.js /root/telegram-webhook/telegram-webhook-server-generalized.js
fi
# Copiar para o arquivo principal
cp /root/telegram-webhook/telegram-webhook-server-generalized.js /root/telegram-webhook/telegram-webhook-server.js

echo "3. Reiniciando serviço..."
systemctl restart telegram-webhook

echo "4. Verificando status..."
sleep 2
systemctl status telegram-webhook --no-pager -l

echo ""
echo "==========================================="
echo "✅ SERVIDOR ATUALIZADO"
echo "==========================================="
echo ""
echo "Agora, quando você adicionar o bot a um novo grupo:"
echo "1. O bot detectará automaticamente"
echo "2. Cadastrará o grupo para a primeira comunidade sem grupo"
echo "3. Enviará uma mensagem de confirmação"
echo ""
