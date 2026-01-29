# ============================================
# VERIFICAR IDENTIFICAÇÃO DE GRUPOS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR IDENTIFICAÇÃO DE GRUPOS" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_identificacao_grupos.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando verificação..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/verificar_identificacao_grupos.sh; /root/verificar_identificacao_grupos.sh'
