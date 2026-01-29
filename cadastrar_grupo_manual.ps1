# ============================================
# CADASTRAR GRUPO MANUALMENTE
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CADASTRAR GRUPO MANUALMENTE" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp cadastrar_grupo_manual.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando cadastro..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/cadastrar_grupo_manual.sh; /root/cadastrar_grupo_manual.sh'
