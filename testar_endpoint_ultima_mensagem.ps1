# ============================================
# TESTAR ENDPOINT COM ÚLTIMA MENSAGEM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TESTAR ENDPOINT COM ÚLTIMA MENSAGEM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp testar_endpoint_ultima_mensagem.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando teste..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/testar_endpoint_ultima_mensagem.sh && /root/testar_endpoint_ultima_mensagem.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
