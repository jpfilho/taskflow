#!/bin/bash
# ============================================
# VERIFICAR SERVIDOR GENERALIZADO
# ============================================

echo "==========================================="
echo "VERIFICAR SERVIDOR GENERALIZADO"
echo "==========================================="
echo ""

echo "1. Verificando se arquivo generalizado existe..."
if [ -f "/root/telegram-webhook-server-generalized.js" ]; then
  echo "   ✅ Arquivo generalizado encontrado"
else
  echo "   ❌ Arquivo generalizado NÃO encontrado!"
  exit 1
fi

echo ""
echo "2. Verificando arquivo atual do servidor..."
if [ -f "/root/telegram-webhook/telegram-webhook-server.js" ]; then
  echo "   ✅ Arquivo atual existe"
  
  # Verificar se contém "ensureTaskTopic" (função do generalizado)
  if grep -q "ensureTaskTopic" /root/telegram-webhook/telegram-webhook-server.js; then
    echo "   ✅ Arquivo atual É o generalizado"
  else
    echo "   ⚠️  Arquivo atual NÃO é o generalizado!"
    echo "   Copiando arquivo generalizado..."
    cp /root/telegram-webhook-server-generalized.js /root/telegram-webhook/telegram-webhook-server.js
    echo "   ✅ Arquivo copiado"
  fi
else
  echo "   ❌ Arquivo atual NÃO existe!"
  exit 1
fi

echo ""
echo "3. Verificando dependência pg..."
cd /root/telegram-webhook
if npm list pg > /dev/null 2>&1; then
  echo "   ✅ Dependência pg instalada"
else
  echo "   ⚠️  Dependência pg não encontrada, instalando..."
  npm install pg
  echo "   ✅ Dependência instalada"
fi

echo ""
echo "4. Testando sintaxe..."
node -c /root/telegram-webhook/telegram-webhook-server.js
if [ $? -eq 0 ]; then
  echo "   ✅ Sintaxe OK"
else
  echo "   ❌ Erro de sintaxe!"
  exit 1
fi

echo ""
echo "5. Reiniciando serviço..."
systemctl restart telegram-webhook
sleep 2

echo ""
echo "6. Verificando status do serviço..."
systemctl status telegram-webhook --no-pager | head -10

echo ""
echo "✅ Verificação concluída!"
