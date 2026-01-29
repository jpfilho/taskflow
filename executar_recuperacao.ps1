# ============================================
# EXECUTAR RECUPERACAO DO NGINX
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RECUPERANDO NGINX" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script para o servidor..." -ForegroundColor Yellow
scp recuperar_nginx.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando no servidor..." -ForegroundColor Yellow
Write-Host ""
ssh $SERVER "chmod +x /root/recuperar_nginx.sh && /root/recuperar_nginx.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Teste agora: http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
