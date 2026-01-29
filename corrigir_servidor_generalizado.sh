#!/bin/bash
# ============================================
# CORRIGIR SERVIDOR GENERALIZADO
# ============================================

echo "==========================================="
echo "CORRIGIR SERVIDOR GENERALIZADO"
echo "==========================================="
echo ""

# Verificar se arquivo generalizado existe
if [ ! -f "/root/telegram-webhook-server-generalized.js" ]; then
  echo "❌ Arquivo generalizado não encontrado em /root/"
  exit 1
fi

echo "1. Copiando arquivo generalizado..."
cp /root/telegram-webhook-server-generalized.js /root/telegram-webhook/telegram-webhook-server.js

echo "2. Instalando dependência pg..."
cd /root/telegram-webhook
npm install pg --save

echo "3. Testando sintaxe..."
node -c telegram-webhook-server.js
if [ $? -ne 0 ]; then
  echo "❌ Erro de sintaxe!"
  exit 1
fi

echo "4. Reiniciando serviço..."
systemctl restart telegram-webhook
sleep 3

echo "5. Verificando se está rodando..."
systemctl is-active telegram-webhook
if [ $? -eq 0 ]; then
  echo "✅ Servidor está rodando!"
else
  echo "❌ Servidor não está rodando!"
  exit 1
fi

echo ""
echo "6. Verificando logs..."
journalctl -u telegram-webhook -n 5 --no-pager

echo ""
echo "✅ Correção concluída!"
