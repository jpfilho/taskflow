# ============================================
# TESTAR ENDPOINT COM MENSAGEM REAL
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TESTAR ENDPOINT COM MENSAGEM REAL" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp testar_endpoint_real.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando teste..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/testar_endpoint_real.sh && /root/testar_endpoint_real.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
