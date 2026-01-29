# ============================================
# CORRIGIR TODOS OS TÓPICOS COM GRUPO ERRADO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR TÓPICOS COM GRUPO ERRADO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar script
Write-Host "Copiando script..." -ForegroundColor Yellow
scp corrigir_todos_topicos_errados.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando correção..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/corrigir_todos_topicos_errados.sh; /root/corrigir_todos_topicos_errados.sh'
