# ============================================
# CORRIGIR SERVIÇO PARA USAR ARQUIVO GENERALIZED
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGINDO SERVIÇO PARA USAR ARQUIVO GENERALIZED" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp corrigir_servico_arquivo.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando correção..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/corrigir_servico_arquivo.sh; /root/corrigir_servico_arquivo.sh'
