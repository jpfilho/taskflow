# ============================================
# ATUALIZAR SERVIDOR COM CORS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ATUALIZAR SERVIDOR COM CORS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando arquivo atualizado do servidor..." -ForegroundColor Yellow
scp telegram-webhook-server.js "${SERVER}:/root/"

Write-Host ""
Write-Host "2. Copiando script de atualização..." -ForegroundColor Yellow
scp atualizar_servidor_cors.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "3. Executando atualização..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/atualizar_servidor_cors.sh && /root/atualizar_servidor_cors.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "SERVIDOR ATUALIZADO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora teste novamente enviando uma mensagem do Flutter!" -ForegroundColor Yellow
Write-Host ""
