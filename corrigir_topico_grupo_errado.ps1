# ============================================
# CORRIGIR TÓPICO APONTANDO PARA GRUPO ERRADO
# ============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId
)

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR TÓPICO PARA GRUPO CORRETO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp corrigir_topico_grupo_errado.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando correção..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/corrigir_topico_grupo_errado.sh; /root/corrigir_topico_grupo_errado.sh '$TaskId'"
