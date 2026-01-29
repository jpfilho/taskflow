# ============================================
# LISTAR TODAS AS VINCULACOES
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "LISTAR TODAS AS VINCULACOES" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp listar_todas_vinculacoes.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/listar_todas_vinculacoes.sh; /root/listar_todas_vinculacoes.sh'
