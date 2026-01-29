# ============================================
# VER LOGS COMPLETOS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "LOGS COMPLETOS DO ERRO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando e executando script..." -ForegroundColor Yellow
scp ver_logs_erro.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/ver_logs_erro.sh && /root/ver_logs_erro.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
