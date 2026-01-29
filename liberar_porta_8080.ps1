# ============================================
# LIBERAR PORTA 8080 NO FIREWALL
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "LIBERANDO PORTA 8080 NO FIREWALL" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Liberando porta 8080/tcp..." -ForegroundColor Yellow
ssh $SERVER "ufw allow 8080/tcp"

Write-Host ""
Write-Host "2. Verificando regras atualizadas..." -ForegroundColor Yellow
ssh $SERVER "ufw status | grep 8080"

Write-Host ""
Write-Host "3. Testando acesso externo..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

$response = curl -I http://212.85.0.249:8080/task2026/ 2>&1
if ($response -match "200 OK") {
    Write-Host "   SUCESSO!" -ForegroundColor Green
} else {
    Write-Host "   Aguarde alguns segundos..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "PORTA 8080 LIBERADA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Teste agora no navegador:" -ForegroundColor Cyan
Write-Host "   http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
Write-Host ""
Write-Host "Se nao abrir, pressione Ctrl+Shift+R" -ForegroundColor Gray
Write-Host ""
