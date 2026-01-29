# Script para ver logs do servidor Telegram webhook

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VER LOGS DO SERVIDOR TELEGRAM" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Ultimas 50 linhas dos logs..." -ForegroundColor Yellow
Write-Host ""

ssh $SERVER 'sudo journalctl -u telegram-webhook -n 50 --no-pager'

Write-Host ""
Write-Host "Para ver logs em tempo real, execute:" -ForegroundColor Yellow
Write-Host "  ssh $SERVER 'sudo journalctl -u telegram-webhook -f'" -ForegroundColor Cyan
