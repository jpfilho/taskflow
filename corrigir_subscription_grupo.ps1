# ============================================
# CORRIGIR SUBSCRIPTION PARA O GRUPO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR SUBSCRIPTION PARA O GRUPO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp corrigir_subscription_grupo.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando correção..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/corrigir_subscription_grupo.sh && /root/corrigir_subscription_grupo.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CORREÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
