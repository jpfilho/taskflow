# Script para configurar Nginx como proxy reverso para N8N
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"  # Ajuste conforme necessário
$N8N_PORT = "5678"
$NGINX_DOMAIN = "n8n.212.85.0.249"  # Ajuste conforme seu domínio

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Configuração do Nginx para N8N" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Criar configuração do Nginx para N8N
Write-Host "[1/3] Criando configuração do Nginx..." -ForegroundColor Yellow

$nginxConfig = @"
server {
    listen 80;
    server_name ${NGINX_DOMAIN};

    # Tamanho máximo de upload (para workflows grandes)
    client_max_body_size 50M;

    location / {
        proxy_pass http://localhost:${N8N_PORT};
        proxy_http_version 1.1;
        
        # Headers necessários para N8N
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        
        # Timeouts
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
        
        # Desabilitar buffering para WebSockets
        proxy_buffering off;
    }
}
"@

# Salvar configuração temporariamente
$nginxConfig | Out-File -FilePath "n8n.conf" -Encoding UTF8

# Copiar para o servidor
Write-Host "[2/3] Copiando configuração para o servidor..." -ForegroundColor Yellow
scp n8n.conf ${SERVER_USER}@${SERVER_IP}:/etc/nginx/sites-available/n8n

# Criar link simbólico e testar
Write-Host "[3/3] Ativando configuração e testando..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} @"
    # Criar link simbólico
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
    
    # Testar configuração
    nginx -t
    
    if [ `$? -eq 0 ]; then
        # Recarregar Nginx
        systemctl reload nginx
        echo 'Configuração do Nginx aplicada com sucesso!'
    else
        echo 'Erro na configuração do Nginx. Verifique o arquivo.'
        exit 1
    fi
"@

# Limpar arquivo temporário
Remove-Item n8n.conf -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Configuração Concluída!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "N8N agora está acessível via Nginx:" -ForegroundColor Yellow
Write-Host "  URL: http://${NGINX_DOMAIN}" -ForegroundColor White
Write-Host ""
Write-Host "Para configurar HTTPS, use Let's Encrypt:" -ForegroundColor Yellow
Write-Host "  certbot --nginx -d ${NGINX_DOMAIN}" -ForegroundColor White
Write-Host ""
