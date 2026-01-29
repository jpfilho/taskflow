# ============================================
# ATUALIZAR SERVIDOR COM AUTO-CADASTRO DE GRUPOS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "ATUALIZANDO SERVIDOR TELEGRAM" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar servidor atualizado
Write-Host "Copiando servidor atualizado..." -ForegroundColor Yellow
scp telegram-webhook-server-generalized.js "${SERVER}:/root/telegram-webhook/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar servidor!" -ForegroundColor Red
    exit 1
}

# Copiar script de atualização
Write-Host "Copiando script de atualização..." -ForegroundColor Yellow
scp atualizar_servidor_auto_grupos.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando atualização..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/atualizar_servidor_auto_grupos.sh; /root/atualizar_servidor_auto_grupos.sh'

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "✅ SERVIDOR ATUALIZADO COM SUCESSO!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora, quando você adicionar o bot a um novo grupo:" -ForegroundColor Yellow
Write-Host "1. O bot detectará automaticamente" -ForegroundColor White
Write-Host "2. Cadastrará o grupo para a primeira comunidade sem grupo" -ForegroundColor White
Write-Host "3. Enviará uma mensagem de confirmação" -ForegroundColor White
Write-Host ""
