# ============================================
# DEPLOY TELEGRAM WEBHOOK - POWERSHELL NATIVO
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_DIR = "/root/telegram-webhook"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DEPLOY TELEGRAM WEBHOOK NODE.JS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Criar diretório
Write-Host "1. Criando diretorio no servidor..." -ForegroundColor Yellow
ssh $SERVER "mkdir -p $REMOTE_DIR"

# 2. Copiar arquivos
Write-Host ""
Write-Host "2. Copiando arquivos..." -ForegroundColor Yellow
scp telegram-webhook-server.js "${SERVER}:${REMOTE_DIR}/"
scp package.json "${SERVER}:${REMOTE_DIR}/"

# 3. Instalar Node.js e dependências
Write-Host ""
Write-Host "3. Instalando Node.js e dependencias..." -ForegroundColor Yellow
ssh $SERVER @'
cd /root/telegram-webhook

# Verificar Node.js
if ! command -v node &> /dev/null; then
    echo "   Instalando Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

echo "   Node: $(node --version)"
echo "   NPM: $(npm --version)"

# Instalar pacotes
echo "   Instalando pacotes NPM..."
npm install
'@

# 4. Criar serviço systemd
Write-Host ""
Write-Host "4. Criando servico systemd..." -ForegroundColor Yellow
ssh $SERVER @'
cat > /etc/systemd/system/telegram-webhook.service << "EOF"
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

systemctl daemon-reload
systemctl enable telegram-webhook
systemctl restart telegram-webhook

sleep 2
systemctl status telegram-webhook --no-pager | head -15
'@

# 5. Configurar Nginx
Write-Host ""
Write-Host "5. Configurando Nginx..." -ForegroundColor Yellow
ssh $SERVER @'
cat > /etc/nginx/sites-available/supabase-ssl << "EOFNGINX"
server {
    listen 80;
    server_name api.taskflowv3.com.br;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    ssl_certificate /etc/letsencrypt/live/api.taskflowv3.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflowv3.com.br/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    client_max_body_size 50M;
    
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
    
    access_log /var/log/nginx/supabase_ssl_access.log;
    error_log /var/log/nginx/supabase_ssl_error.log;
}
EOFNGINX

nginx -t && systemctl reload nginx
'@

# 6. Configurar webhook
Write-Host ""
Write-Host "6. Configurando webhook do Telegram..." -ForegroundColor Yellow
$webhookUrl = "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/setWebhook"
$body = @{
    url = "https://api.taskflowv3.com.br/telegram-webhook"
    secret_token = "TgWebhook2026Taskflow_Secret"
    allowed_updates = @("message", "edited_message", "callback_query")
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json"

if ($response.ok) {
    Write-Host "   Webhook configurado!" -ForegroundColor Green
    Write-Host "   $($response.description)" -ForegroundColor Gray
} else {
    Write-Host "   ERRO: $($response.description)" -ForegroundColor Red
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Servico: telegram-webhook" -ForegroundColor White
Write-Host "Porta: 3001 (local)" -ForegroundColor White
Write-Host "URL: https://api.taskflowv3.com.br/telegram-webhook" -ForegroundColor White
Write-Host ""
Write-Host "Comandos uteis:" -ForegroundColor Cyan
Write-Host "  ssh root@212.85.0.249 'systemctl status telegram-webhook'" -ForegroundColor Gray
Write-Host "  ssh root@212.85.0.249 'systemctl restart telegram-webhook'" -ForegroundColor Gray
Write-Host "  ssh root@212.85.0.249 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
Write-Host "TESTE AGORA:" -ForegroundColor Yellow
Write-Host "  Envie uma mensagem no grupo do Telegram!" -ForegroundColor White
Write-Host ""
