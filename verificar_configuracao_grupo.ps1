# ============================================
# VERIFICAR CONFIGURAÇÃO DO GRUPO TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR CONFIGURAÇÃO DO GRUPO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_configuracao_grupo.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando verificação..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/verificar_configuracao_grupo.sh; /root/verificar_configuracao_grupo.sh'
