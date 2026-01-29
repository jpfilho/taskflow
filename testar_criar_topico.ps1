# ============================================
# TESTAR CRIACAO DE TOPICO NO TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "TESTAR CRIACAO DE TOPICO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp testar_criar_topico.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando teste..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/testar_criar_topico.sh; /root/testar_criar_topico.sh'
