# ============================================
# VERIFICAR CONFIGURACAO DO SERVIDOR WEB
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICANDO SERVIDOR WEB" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando qual servidor web esta rodando..." -ForegroundColor Yellow
ssh $SERVER "ps aux | grep -E 'nginx|apache' | grep -v grep"

Write-Host ""
Write-Host "2. Verificando portas abertas..." -ForegroundColor Yellow
ssh $SERVER "netstat -tulpn | grep -E ':80|:8080|:8000'"

Write-Host ""
Write-Host "3. Verificando configuracao do Nginx..." -ForegroundColor Yellow
ssh $SERVER "ls -la /etc/nginx/sites-enabled/"

Write-Host ""
Write-Host "4. Conteudo da configuracao do site..." -ForegroundColor Yellow
ssh $SERVER "cat /etc/nginx/sites-enabled/default | grep -A 20 'server {'"

Write-Host ""
Write-Host "5. Testando acesso direto ao index.html..." -ForegroundColor Yellow
ssh $SERVER "curl -I http://localhost:8080/task2026/index.html"

Write-Host ""
Write-Host "6. Verificando logs de erro do Nginx..." -ForegroundColor Yellow
ssh $SERVER "tail -20 /var/log/nginx/error.log"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
