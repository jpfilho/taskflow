# ============================================
# TESTAR ENVIO DIRETO PARA TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TESTAR ENVIO DIRETO PARA TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp testar_envio_direto.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando teste..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/testar_envio_direto.sh && /root/testar_envio_direto.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
