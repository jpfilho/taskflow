# ============================================
# VER LOGS DO TELEGRAM WEBHOOK
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "LOGS DO TELEGRAM WEBHOOK" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Ultimas 50 linhas de log:" -ForegroundColor Yellow
Write-Host ""
ssh $SERVER "journalctl -u telegram-webhook -n 50 --no-pager"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para ver logs em tempo real, execute:" -ForegroundColor Yellow
Write-Host "  ssh root@212.85.0.249 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
