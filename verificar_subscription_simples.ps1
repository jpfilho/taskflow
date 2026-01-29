# ============================================
# VERIFICAR SUBSCRIPTION - SIMPLES
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR SUBSCRIPTION" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando e executando script..." -ForegroundColor Yellow
scp verificar_subscription.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/verificar_subscription.sh && /root/verificar_subscription.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
