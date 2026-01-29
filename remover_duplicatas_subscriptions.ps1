# ============================================
# REMOVER SUBSCRIPTIONS DUPLICADAS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "REMOVER SUBSCRIPTIONS DUPLICADAS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp remover_duplicatas_subscriptions.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando remoção..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/remover_duplicatas_subscriptions.sh && /root/remover_duplicatas_subscriptions.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DUPLICATAS REMOVIDAS!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
