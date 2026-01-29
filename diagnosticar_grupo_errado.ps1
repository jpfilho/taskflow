# ============================================
# DIAGNOSTICAR POR QUE MENSAGEM FOI PARA GRUPO ERRADO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICAR GRUPO ERRADO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp diagnosticar_grupo_errado.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando diagnóstico..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/diagnosticar_grupo_errado.sh; /root/diagnosticar_grupo_errado.sh'
