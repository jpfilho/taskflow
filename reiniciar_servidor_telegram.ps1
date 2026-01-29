# Script para reiniciar o servidor telegram-webhook

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "REINICIAR SERVIDOR TELEGRAM-WEBHOOK" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Parando servico..." -ForegroundColor Yellow
ssh $SERVER 'sudo systemctl stop telegram-webhook'

if ($LASTEXITCODE -eq 0) {
    Write-Host "Servico parado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "Aviso: Erro ao parar servico (pode ja estar parado)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Iniciando servico..." -ForegroundColor Yellow
ssh $SERVER 'sudo systemctl start telegram-webhook'

if ($LASTEXITCODE -eq 0) {
    Write-Host "Servico iniciado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "Erro ao iniciar servico!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Verificando status..." -ForegroundColor Yellow
ssh $SERVER 'sudo systemctl status telegram-webhook --no-pager -l'

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Servico reiniciado!" -ForegroundColor Green
Write-Host "Para ver logs em tempo real:" -ForegroundColor Yellow
Write-Host "ssh $SERVER 'sudo journalctl -u telegram-webhook -f'" -ForegroundColor Cyan
Write-Host ""
