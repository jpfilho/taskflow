# Script para verificar logs do servidor Node.js

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR LOGS DO SERVIDOR TELEGRAM" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Buscando ultimas 100 linhas dos logs..." -ForegroundColor Yellow
Write-Host ""

ssh $SERVER 'sudo journalctl -u telegram-webhook -n 100 --no-pager'

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Para ver logs em tempo real:" -ForegroundColor Yellow
Write-Host "ssh $SERVER 'sudo journalctl -u telegram-webhook -f'" -ForegroundColor Cyan
Write-Host ""
