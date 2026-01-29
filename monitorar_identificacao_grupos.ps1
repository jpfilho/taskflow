# ============================================
# MONITORAR IDENTIFICAÇÃO DE GRUPOS EM TEMPO REAL
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "MONITORANDO IDENTIFICAÇÃO DE GRUPOS" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pressione Ctrl+C para parar" -ForegroundColor Yellow
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp monitorar_identificacao_grupos.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Iniciando monitoramento..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/monitorar_identificacao_grupos.sh; /root/monitorar_identificacao_grupos.sh'
