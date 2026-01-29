# Script para verificar qual arquivo o servico esta usando

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR ARQUIVO DO SERVICO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Verificando arquivo do systemd service..." -ForegroundColor Yellow
ssh $SERVER 'cat /etc/systemd/system/telegram-webhook.service'

Write-Host ""
Write-Host "Verificando se o arquivo generalized existe..." -ForegroundColor Yellow
ssh $SERVER 'ls -la /root/telegram-webhook/telegram-webhook-server*.js'

Write-Host ""
