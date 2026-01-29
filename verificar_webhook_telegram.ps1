# ============================================
# VERIFICAR CONFIGURACAO DO WEBHOOK
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR CONFIGURACAO DO WEBHOOK" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_webhook_telegram.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/verificar_webhook_telegram.sh; /root/verificar_webhook_telegram.sh'
