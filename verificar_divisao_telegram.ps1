# ============================================
# VERIFICAR DIVISÃO ESPECÍFICA NO TELEGRAM
# ============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$DivisaoNome
)

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR DIVISÃO: $DivisaoNome" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_divisao_telegram.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando verificação..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/verificar_divisao_telegram.sh; /root/verificar_divisao_telegram.sh '$DivisaoNome'"
