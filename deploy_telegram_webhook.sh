#!/bin/bash
# ============================================
# DEPLOY TELEGRAM WEBHOOK NODE.JS
# ============================================

SERVER="root@212.85.0.249"
REMOTE_DIR="/root/telegram-webhook"

echo "=========================================="
echo "DEPLOY TELEGRAM WEBHOOK NODE.JS"
echo "=========================================="
echo ""

# 1. Criar diretório no servidor
echo "1. Criando diretório no servidor..."
ssh $SERVER "mkdir -p $REMOTE_DIR"

# 2. Copiar arquivos
echo ""
echo "2. Copiando arquivos..."
scp telegram-webhook-server.js $SERVER:$REMOTE_DIR/
scp package.json $SERVER:$REMOTE_DIR/

# 3. Instalar dependências
echo ""
echo "3. Instalando dependências..."
ssh $SERVER << 'ENDSSH'
cd /root/telegram-webhook

# Instalar Node.js se necessário
if ! command -v node &> /dev/null; then
    echo "   Instalando Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

echo "   Node version: $(node --version)"
echo "   NPM version: $(npm --version)"

# Instalar dependências
echo "   Instalando pacotes NPM..."
npm install

ENDSSH

# 4. Criar systemd service
echo ""
echo "4. Criando serviço systemd..."
ssh $SERVER << 'ENDSSH'
cat > /etc/systemd/system/telegram-webhook.service << 'EOF'
[Unit]
Description=TaskFlow Telegram Webhook Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/telegram-webhook
ExecStart=/usr/bin/node /root/telegram-webhook/telegram-webhook-server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3001
Environment=TELEGRAM_BOT_TOKEN=8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec
Environment=TELEGRAM_WEBHOOK_SECRET=TgWebhook2026Taskflow_Secret
Environment=SUPABASE_URL=http://127.0.0.1:8000
Environment=SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd
systemctl daemon-reload

# Iniciar serviço
systemctl enable telegram-webhook
systemctl restart telegram-webhook

# Verificar status
sleep 2
systemctl status telegram-webhook --no-pager | head -15

ENDSSH

# 5. Configurar Nginx
echo ""
echo "5. Configurando Nginx..."
ssh $SERVER << 'ENDSSH'
# Adicionar proxy no arquivo supabase-ssl
cat > /etc/nginx/sites-available/supabase-ssl << 'EOFNGINX'
# HTTP -> HTTPS redirect
server {
    listen 80;
    server_name api.taskflowv3.com.br;
    return 301 https://$server_name$request_uri;
}

# HTTPS para Supabase + Telegram Webhook
server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/api.taskflowv3.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflowv3.com.br/privkey.pem;
    
    # Configurações SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    client_max_body_size 50M;
    
    # Telegram Webhook (Node.js na porta 3001)
    location /telegram-webhook {
        proxy_pass http://127.0.0.1:3001/telegram-webhook;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header x-telegram-bot-api-secret-token $http_x_telegram_bot_api_secret_token;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Supabase (porta 8000)
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_buffering off;
    }
    
    # Logs
    access_log /var/log/nginx/supabase_ssl_access.log;
    error_log /var/log/nginx/supabase_ssl_error.log;
}
EOFNGINX

# Testar e recarregar Nginx
nginx -t && systemctl reload nginx

ENDSSH

# 6. Configurar webhook do Telegram
echo ""
echo "6. Configurando webhook do Telegram..."
curl -X POST "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://api.taskflowv3.com.br/telegram-webhook",
    "secret_token": "TgWebhook2026Taskflow_Secret",
    "allowed_updates": ["message", "edited_message", "callback_query"]
  }'

echo ""
echo ""
echo "=========================================="
echo "✅ DEPLOY CONCLUÍDO!"
echo "=========================================="
echo ""
echo "Serviço: telegram-webhook"
echo "Porta: 3001 (local)"
echo "URL: https://api.taskflowv3.com.br/telegram-webhook"
echo ""
echo "Comandos úteis:"
echo "  systemctl status telegram-webhook"
echo "  systemctl restart telegram-webhook"
echo "  journalctl -u telegram-webhook -f"
echo ""
