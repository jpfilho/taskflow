# ============================================
# CORRIGIR CONFIGURACAO DO NGINX
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGINDO NGINX" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando configuracao atual..." -ForegroundColor Yellow
ssh $SERVER "cat /etc/nginx/sites-available/task2026"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Pressione qualquer tecla para continuar com a correcao..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "2. Criando configuracao correta..." -ForegroundColor Yellow
ssh $SERVER @'
cat > /etc/nginx/sites-available/task2026 << 'EOF'
server {
    listen 8080;
    listen [::]:8080;
    
    server_name 212.85.0.249 taskflowv3.com.br www.taskflowv3.com.br;
    
    root /var/www/html;
    index index.html;
    
    # Location para /task2026/
    location /task2026/ {
        alias /var/www/html/task2026/;
        try_files $uri $uri/ /task2026/index.html;
        
        # Headers para Flutter Web
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
        
        # CORS headers
        add_header Access-Control-Allow-Origin "*";
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type";
    }
    
    # Redirecionar / para /task2026/
    location = / {
        return 301 /task2026/;
    }
    
    # Logs
    access_log /var/log/nginx/task2026_access.log;
    error_log /var/log/nginx/task2026_error.log;
}
EOF
'@

Write-Host ""
Write-Host "3. Testando configuracao do Nginx..." -ForegroundColor Yellow
ssh $SERVER "nginx -t"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "4. Recarregando Nginx..." -ForegroundColor Yellow
    ssh $SERVER "systemctl reload nginx"
    
    Write-Host ""
    Write-Host "5. Verificando status do Nginx..." -ForegroundColor Yellow
    ssh $SERVER "systemctl status nginx | head -10"
    
    Write-Host ""
    Write-Host "6. Testando acesso..." -ForegroundColor Yellow
    ssh $SERVER "curl -I http://localhost:8080/task2026/"
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "NGINX CORRIGIDO!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Teste agora no navegador:" -ForegroundColor Cyan
    Write-Host "   http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "ERRO na configuracao do Nginx!" -ForegroundColor Red
    Write-Host "Verifique os erros acima." -ForegroundColor Red
}
