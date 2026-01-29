#!/bin/bash
# ============================================
# VERIFICAR E CORRIGIR NGINX PARA /send-message
# ============================================

echo "1. Verificando qual arquivo de configuração está ativo..."
ls -la /etc/nginx/sites-enabled/

echo ""
echo "2. Verificando se /send-message já existe..."
if grep -r "location /send-message" /etc/nginx/sites-available/; then
  echo "✅ Location /send-message já existe!"
  exit 0
fi

echo ""
echo "3. Identificando arquivo de configuração principal..."
CONFIG_FILE=""
if [ -f "/etc/nginx/sites-available/supabase-ssl" ]; then
  CONFIG_FILE="/etc/nginx/sites-available/supabase-ssl"
elif [ -f "/etc/nginx/sites-available/default" ]; then
  CONFIG_FILE="/etc/nginx/sites-available/default"
else
  echo "❌ Arquivo de configuração não encontrado!"
  exit 1
fi

echo "   Usando: $CONFIG_FILE"

echo ""
echo "4. Fazendo backup..."
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

echo ""
echo "5. Adicionando location /send-message..."

# Criar bloco de configuração
SEND_MESSAGE_BLOCK='    location /send-message {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }'

# Encontrar onde inserir (antes de location /telegram-webhook ou antes de location /)
if grep -q "location /telegram-webhook" "$CONFIG_FILE"; then
  # Inserir antes de /telegram-webhook
  sed -i "/location \/telegram-webhook/i\\$SEND_MESSAGE_BLOCK" "$CONFIG_FILE"
  echo "   ✅ Inserido antes de /telegram-webhook"
else
  # Inserir antes do primeiro location /
  sed -i "/location \//i\\$SEND_MESSAGE_BLOCK" "$CONFIG_FILE"
  echo "   ✅ Inserido antes de location /"
fi

echo ""
echo "6. Testando configuração..."
if nginx -t; then
  echo ""
  echo "7. Recarregando Nginx..."
  systemctl reload nginx
  echo "✅ Nginx configurado e recarregado com sucesso!"
  
  echo ""
  echo "8. Verificando se foi adicionado..."
  grep -A 10 "location /send-message" "$CONFIG_FILE"
else
  echo "❌ Erro na configuração do Nginx!"
  echo "   Restaurando backup..."
  cp "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)" "$CONFIG_FILE"
  exit 1
fi
