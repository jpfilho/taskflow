#!/bin/bash
# ============================================
# VERIFICAR E CORRIGIR NGINX PARA /send-message
# ============================================

echo "1. Verificando configuração atual do Nginx..."
cat /etc/nginx/sites-available/default | grep -A 20 "server {" | head -30

echo ""
echo "2. Verificando se há location /send-message..."
grep -n "location /send-message" /etc/nginx/sites-available/default || echo "❌ Location /send-message NÃO encontrado!"

echo ""
echo "3. Adicionando location /send-message..."

# Backup da configuração
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)

# Criar script temporário para adicionar location
cat > /tmp/adicionar_send_message.sh << 'EOF'
#!/bin/bash
CONFIG_FILE="/etc/nginx/sites-available/default"

# Verificar se já existe
if grep -q "location /send-message" "$CONFIG_FILE"; then
  echo "Location /send-message já existe!"
  exit 0
fi

# Encontrar o bloco server e adicionar location antes do fechamento
# Procurar por "location /" ou "location /telegram-webhook" e adicionar depois
if grep -q "location /telegram-webhook" "$CONFIG_FILE"; then
  # Adicionar depois de telegram-webhook
  sed -i '/location \/telegram-webhook/,/}/a\
    location /send-message {\
        proxy_pass http://127.0.0.1:3001;\
        proxy_http_version 1.1;\
        proxy_set_header Upgrade $http_upgrade;\
        proxy_set_header Connection '\''upgrade'\'';\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
        proxy_cache_bypass $http_upgrade;\
    }' "$CONFIG_FILE"
else
  # Adicionar dentro do bloco server, antes do fechamento
  sed -i '/server {/,/^}/ {
    /^}/i\
    location /send-message {\
        proxy_pass http://127.0.0.1:3001;\
        proxy_http_version 1.1;\
        proxy_set_header Upgrade $http_upgrade;\
        proxy_set_header Connection '\''upgrade'\'';\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
        proxy_cache_bypass $http_upgrade;\
    }
  }' "$CONFIG_FILE"
fi

echo "✅ Location /send-message adicionado!"
EOF

chmod +x /tmp/adicionar_send_message.sh
/tmp/adicionar_send_message.sh

echo ""
echo "4. Testando configuração do Nginx..."
nginx -t

if [ $? -eq 0 ]; then
  echo ""
  echo "5. Recarregando Nginx..."
  systemctl reload nginx
  echo "✅ Nginx recarregado!"
else
  echo "❌ Erro na configuração do Nginx!"
  exit 1
fi

echo ""
echo "6. Verificando se o location foi adicionado..."
grep -A 10 "location /send-message" /etc/nginx/sites-available/default
