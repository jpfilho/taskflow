# ============================================
# CORRIGIR SERVIDOR GENERALIZADO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR SERVIDOR GENERALIZADO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script de correção..." -ForegroundColor Yellow
scp corrigir_servidor_generalizado.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando correção..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/corrigir_servidor_generalizado.sh && /root/corrigir_servidor_generalizado.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Green
    Write-Host "CORREÇÃO CONCLUÍDA!" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Erro na correção!" -ForegroundColor Red
    exit 1
}
