# ============================================
# EXECUTAR VINCULACAO DO EXECUTOR
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VINCULAR EXECUTOR AO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp vincular_simples.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando vinculacao..." -ForegroundColor Yellow
ssh $SERVER "cd /root && chmod +x vincular_simples.sh && ./vincular_simples.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Proximo passo:" -ForegroundColor Yellow
Write-Host "  1. Envie uma mensagem no Telegram" -ForegroundColor White
Write-Host "  2. Execute: .\testar_webhook.ps1" -ForegroundColor White
Write-Host ""
