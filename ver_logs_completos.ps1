# ============================================
# VER LOGS COMPLETOS DO ERRO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "LOGS COMPLETOS DO ERRO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Ultimos 50 logs do servidor:" -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 50 --no-pager"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
