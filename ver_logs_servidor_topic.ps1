# ============================================
# VER LOGS DO SERVIDOR - TOPICOS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "LOGS DO SERVIDOR - TOPICOS" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp ver_logs_servidor_topic.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/ver_logs_servidor_topic.sh; /root/ver_logs_servidor_topic.sh'
