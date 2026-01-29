# ============================================
# VERIFICAR SE O GRUPO FOI CADASTRADO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR SE O GRUPO FOI CADASTRADO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_grupo_criado.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando verificação..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/verificar_grupo_criado.sh; /root/verificar_grupo_criado.sh'
