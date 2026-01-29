# ============================================
# BUSCAR COMUNIDADE POR TELEGRAM CHAT ID
# ============================================

$SERVER = "root@212.85.0.249"
$TELEGRAM_CHAT_ID = "-1003721115749"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "BUSCAR COMUNIDADE POR TELEGRAM CHAT ID" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Telegram Chat ID: $TELEGRAM_CHAT_ID" -ForegroundColor Yellow
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp buscar_comunidade_por_chat_id.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/buscar_comunidade_por_chat_id.sh; /root/buscar_comunidade_por_chat_id.sh $TELEGRAM_CHAT_ID"
