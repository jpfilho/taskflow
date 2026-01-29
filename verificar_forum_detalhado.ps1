# ============================================
# VERIFICAR FORUM DETALHADO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR FORUM DETALHADO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_forum_detalhado.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando verificacao..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/verificar_forum_detalhado.sh; /root/verificar_forum_detalhado.sh'
