# ============================================
# DIAGNOSTICAR E RECUPERAR NGINX
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Red
Write-Host "DIAGNOSTICANDO PROBLEMA" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Red
Write-Host ""

Write-Host "1. Verificando se o Nginx esta rodando..." -ForegroundColor Yellow
ssh $SERVER "systemctl status nginx --no-pager | head -15"

Write-Host ""
Write-Host "2. Verificando portas abertas..." -ForegroundColor Yellow
ssh $SERVER "netstat -tulpn | grep -E ':8080|nginx'"

Write-Host ""
Write-Host "3. Verificando logs de erro do Nginx..." -ForegroundColor Yellow
ssh $SERVER "tail -30 /var/log/nginx/error.log"

Write-Host ""
Write-Host "4. Testando configuracao do Nginx..." -ForegroundColor Yellow
ssh $SERVER "nginx -t"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TENTANDO RECUPERAR..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "5. Restaurando backup da configuracao..." -ForegroundColor Yellow
ssh $SERVER @"
if [ -f /etc/nginx/sites-available/task2026.backup.* ]; then
    LATEST_BACKUP=\$(ls -t /etc/nginx/sites-available/task2026.backup.* | head -1)
    echo "Restaurando: \$LATEST_BACKUP"
    cp \$LATEST_BACKUP /etc/nginx/sites-available/task2026
else
    echo "Nenhum backup encontrado, criando configuracao basica..."
    cat > /etc/nginx/sites-available/task2026 << 'EOFNGINX'
server {
    listen 8080;
    listen [::]:8080;
    
    server_name 212.85.0.249;
    
    location /task2026/ {
        alias /var/www/html/task2026/;
        index index.html;
        try_files \$uri \$uri/ /task2026/index.html;
    }
    
    location = /task2026 {
        return 301 /task2026/;
    }
}
EOFNGINX
fi
"@

Write-Host ""
Write-Host "6. Testando nova configuracao..." -ForegroundColor Yellow
$testResult = ssh $SERVER "nginx -t 2>&1"
Write-Host $testResult

if ($testResult -match "successful") {
    Write-Host ""
    Write-Host "7. Reiniciando Nginx..." -ForegroundColor Yellow
    ssh $SERVER "systemctl restart nginx"
    
    Start-Sleep -Seconds 2
    
    Write-Host ""
    Write-Host "8. Verificando status..." -ForegroundColor Yellow
    ssh $SERVER "systemctl status nginx --no-pager | head -10"
    
    Write-Host ""
    Write-Host "9. Testando acesso..." -ForegroundColor Yellow
    ssh $SERVER "curl -I http://localhost:8080/task2026/ 2>/dev/null | head -10"
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "RECUPERACAO CONCLUIDA!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Teste novamente no navegador:" -ForegroundColor Cyan
    Write-Host "   http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "ERRO: Configuracao do Nginx invalida!" -ForegroundColor Red
    Write-Host "Detalhes:" -ForegroundColor Red
    Write-Host $testResult
}
