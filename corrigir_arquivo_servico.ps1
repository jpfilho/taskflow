# Script para corrigir o arquivo usado pelo servico

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR ARQUIVO DO SERVICO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "IMPORTANTE: Este script vai alterar o arquivo do systemd service" -ForegroundColor Yellow
Write-Host "para usar telegram-webhook-server-generalized.js" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Deseja continuar? (S/N)"

if ($confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Cancelado." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Criando backup do arquivo atual..." -ForegroundColor Yellow
ssh $SERVER 'sudo cp /etc/systemd/system/telegram-webhook.service /etc/systemd/system/telegram-webhook.service.backup'

Write-Host ""
Write-Host "Atualizando arquivo do service..." -ForegroundColor Yellow

$serviceContent = @"
[Unit]
Description=TaskFlow Telegram Webhook Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/telegram-webhook
Environment=NODE_ENV=production
Environment=PORT=3001
ExecStart=/usr/bin/node /root/telegram-webhook/telegram-webhook-server-generalized.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"@

# Salvar conteudo em arquivo temporario
$tempFile = [System.IO.Path]::GetTempFileName()
$serviceContent | Out-File -FilePath $tempFile -Encoding UTF8

# Copiar para o servidor
scp $tempFile "${SERVER}:/tmp/telegram-webhook.service"

# Aplicar no servidor
ssh $SERVER 'sudo mv /tmp/telegram-webhook.service /etc/systemd/system/telegram-webhook.service && sudo systemctl daemon-reload'

# Limpar arquivo temporario
Remove-Item $tempFile

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Arquivo atualizado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Reiniciando servico..." -ForegroundColor Yellow
    ssh $SERVER 'sudo systemctl restart telegram-webhook'
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Servico reiniciado com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Verificando status..." -ForegroundColor Yellow
        ssh $SERVER 'sudo systemctl status telegram-webhook --no-pager -l | head -20'
    }
} else {
    Write-Host ""
    Write-Host "Erro ao atualizar arquivo!" -ForegroundColor Red
}
