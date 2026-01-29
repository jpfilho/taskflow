# ============================================
# DEPLOY NODE.JS TELEGRAM WEBHOOK - RÁPIDO
# ============================================
# Atualiza apenas o arquivo Node.js e reinicia o serviço

$SERVER = "root@212.85.0.249"
$REMOTE_DIR = "/root/telegram-webhook"
$NODE_FILE = "telegram-webhook-server-generalized.js"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DEPLOY NODE.JS TELEGRAM WEBHOOK" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se arquivo existe localmente
Write-Host "1. Verificando arquivo local..." -ForegroundColor Yellow
if (-not (Test-Path $NODE_FILE)) {
    Write-Host "   [ERRO] Arquivo $NODE_FILE não encontrado!" -ForegroundColor Red
    Write-Host "   Certifique-se de estar no diretório correto" -ForegroundColor Yellow
    exit 1
}
Write-Host "   [OK] Arquivo encontrado: $NODE_FILE" -ForegroundColor Green

Write-Host ""

# 2. Fazer backup do arquivo atual no servidor
Write-Host "2. Fazendo backup do arquivo atual no servidor..." -ForegroundColor Yellow
$backupCmd = "cp $REMOTE_DIR/$NODE_FILE $REMOTE_DIR/${NODE_FILE}.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || echo 'Arquivo não existe ainda'"
$backupResult = ssh $SERVER $backupCmd
Write-Host "   Backup: $backupResult" -ForegroundColor Gray

Write-Host ""

# 3. Verificar qual arquivo o serviço está usando
Write-Host "3. Verificando qual arquivo o serviço está usando..." -ForegroundColor Yellow
$serviceFile = ssh $SERVER "grep 'ExecStart' /etc/systemd/system/telegram-webhook.service 2>/dev/null | grep -o '/root/telegram-webhook/[^ ]*' | head -1"
if ($serviceFile) {
    Write-Host "   Serviço usa: $serviceFile" -ForegroundColor Gray
    $targetFile = $serviceFile -replace '/root/telegram-webhook/', ''
} else {
    Write-Host "   [INFO] Não foi possível detectar arquivo do serviço, usando padrão" -ForegroundColor Yellow
    $targetFile = "telegram-webhook-server-generalized.js"
}

Write-Host ""

# 4. Copiar arquivo atualizado
Write-Host "4. Copiando arquivo atualizado para o servidor..." -ForegroundColor Yellow
Write-Host "   De: $NODE_FILE" -ForegroundColor Gray
Write-Host "   Para: $REMOTE_DIR/$targetFile" -ForegroundColor Gray

scp $NODE_FILE "${SERVER}:${REMOTE_DIR}/$targetFile"

if ($LASTEXITCODE -ne 0) {
    Write-Host "   [ERRO] Falha ao copiar arquivo!" -ForegroundColor Red
    exit 1
}
Write-Host "   [OK] Arquivo copiado com sucesso!" -ForegroundColor Green

# Se o serviço usa nome diferente, também copiar com o nome correto
if ($targetFile -ne $NODE_FILE) {
    Write-Host "   [INFO] Serviço usa nome diferente, arquivo também copiado como $targetFile" -ForegroundColor Gray
}

Write-Host ""

# 5. Verificar se serviço existe
Write-Host "5. Verificando serviço systemd..." -ForegroundColor Yellow
$serviceStatus = ssh $SERVER "systemctl is-active telegram-webhook 2>&1"
if ($serviceStatus -match "active|inactive") {
    Write-Host "   [OK] Serviço encontrado (status: $serviceStatus)" -ForegroundColor Green
} else {
    Write-Host "   [ATENÇÃO] Serviço pode não estar configurado" -ForegroundColor Yellow
    Write-Host "   Execute: .\deploy_telegram_completo.ps1 para configurar tudo" -ForegroundColor Gray
}

Write-Host ""

# 6. Reiniciar serviço
Write-Host "6. Reiniciando serviço telegram-webhook..." -ForegroundColor Yellow
ssh $SERVER "systemctl restart telegram-webhook"

if ($LASTEXITCODE -ne 0) {
    Write-Host "   [ERRO] Falha ao reiniciar serviço!" -ForegroundColor Red
    exit 1
}

Write-Host "   Aguardando 3 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 3

Write-Host ""

# 7. Verificar status do serviço
Write-Host "7. Verificando status do serviço..." -ForegroundColor Yellow
$status = ssh $SERVER "systemctl status telegram-webhook --no-pager | head -15"
$status | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }

$isActive = ssh $SERVER "systemctl is-active telegram-webhook"
if ($isActive -match "active") {
    Write-Host "   [OK] Serviço está ativo!" -ForegroundColor Green
} else {
    Write-Host "   [ERRO] Serviço não está ativo!" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Verificando logs de erro..." -ForegroundColor Yellow
    ssh $SERVER "journalctl -u telegram-webhook -n 20 --no-pager | tail -10"
    exit 1
}

Write-Host ""

# 8. Verificar logs recentes
Write-Host "8. Verificando logs recentes..." -ForegroundColor Yellow
$logs = ssh $SERVER "journalctl -u telegram-webhook -n 10 --no-pager"
$logs | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUÍDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "1. Teste deletar uma mensagem no Flutter" -ForegroundColor Yellow
Write-Host "2. Monitore os logs em tempo real:" -ForegroundColor Yellow
Write-Host "   ssh $SERVER 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
