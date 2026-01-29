# ============================================
# VERIFICAR TUDO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR STATUS COMPLETO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando e executando script..." -ForegroundColor Yellow
scp verificar_tudo.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/verificar_tudo.sh && /root/verificar_tudo.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
