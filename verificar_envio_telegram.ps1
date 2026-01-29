# ============================================
# VERIFICAR ENVIO FLUTTER -> TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR ENVIO FLUTTER -> TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_envio_telegram.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando verificação..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/verificar_envio_telegram.sh && /root/verificar_envio_telegram.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
