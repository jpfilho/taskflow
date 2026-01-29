# ============================================
# DIAGNOSTICAR CRIACAO DE TOPICOS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICAR CRIACAO DE TOPICOS" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script de diagnostico..." -ForegroundColor Yellow
scp diagnosticar_topic_creation.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando diagnostico..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/diagnosticar_topic_creation.sh; /root/diagnosticar_topic_creation.sh'

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Green
    Write-Host "DIAGNOSTICO CONCLUIDO!" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Erro no diagnostico!" -ForegroundColor Red
    exit 1
}
