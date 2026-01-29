# ============================================
# VERIFICAR E CORRIGIR NGINX PARA /send-message
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR E CORRIGIR NGINX /send-message" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar qual arquivo de configuração está ativo
Write-Host "1. Verificando arquivos de configuracao..." -ForegroundColor Yellow
ssh $SERVER "ls -la /etc/nginx/sites-enabled/"

Write-Host ""
Write-Host "2. Verificando se location /send-message existe..." -ForegroundColor Yellow
$nginxConfig = ssh $SERVER "grep -r 'location /send-message' /etc/nginx/sites-available/ /etc/nginx/sites-enabled/ 2>/dev/null"
if ($nginxConfig) {
    Write-Host "   [OK] Location /send-message encontrado:" -ForegroundColor Green
    Write-Host "   $nginxConfig" -ForegroundColor Gray
    ssh $SERVER "grep -A 10 'location /send-message' /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* 2>/dev/null | head -20"
} else {
    Write-Host "   [ERRO] Location /send-message NAO encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "3. Identificando arquivo de configuracao principal..." -ForegroundColor Yellow
    $configFile = ssh $SERVER "if [ -f '/etc/nginx/sites-available/supabase-ssl' ]; then echo 'supabase-ssl'; elif [ -f '/etc/nginx/sites-available/default' ]; then echo 'default'; else echo 'notfound'; fi"
    Write-Host "   Arquivo: $configFile" -ForegroundColor Gray
    
    if ($configFile -ne "notfound") {
        Write-Host ""
        Write-Host "4. Adicionando location /send-message..." -ForegroundColor Yellow
        ssh $SERVER @"
CONFIG_FILE="/etc/nginx/sites-available/$configFile"

# Backup
cp "\$CONFIG_FILE" "\${CONFIG_FILE}.backup.\$(date +%Y%m%d_%H%M%S)"

# Verificar se ja existe
if grep -q "location /send-message" "\$CONFIG_FILE"; then
  echo "Location /send-message ja existe!"
  exit 0
fi

# Criar bloco de configuracao
SEND_MESSAGE_BLOCK='    location /send-message {
        proxy_pass http://127.0.0.1:3001/send-message;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }'

# Encontrar onde inserir (antes de location /telegram-webhook ou antes de location /)
if grep -q "location /telegram-webhook" "\$CONFIG_FILE"; then
  # Inserir antes de /telegram-webhook
  sed -i "/location \/telegram-webhook/i\\\$SEND_MESSAGE_BLOCK" "\$CONFIG_FILE"
  echo "Inserido antes de /telegram-webhook"
else
  # Inserir antes do primeiro location /
  sed -i "/location \//i\\\$SEND_MESSAGE_BLOCK" "\$CONFIG_FILE"
  echo "Inserido antes de location /"
fi

# Testar configuracao
if nginx -t; then
  systemctl reload nginx
  echo "Nginx recarregado com sucesso!"
else
  echo "ERRO: Configuracao do Nginx invalida!"
  exit 1
fi
"@
        
        Write-Host ""
        Write-Host "5. Verificando se foi adicionado..." -ForegroundColor Yellow
        ssh $SERVER "grep -A 10 'location /send-message' /etc/nginx/sites-available/$configFile"
    } else {
        Write-Host "   [ERRO] Arquivo de configuracao nao encontrado!" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Para testar novamente, execute:" -ForegroundColor Yellow
Write-Host "  .\testar_servidor_telegram_rapido.ps1" -ForegroundColor White
Write-Host ""
