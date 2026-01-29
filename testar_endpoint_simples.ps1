# ============================================
# TESTAR ENDPOINT - VERSÃO SIMPLES
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TESTAR ENDPOINT /send-message" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando script de teste..." -ForegroundColor Yellow
scp testar_endpoint.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/testar_endpoint.sh"

Write-Host ""
Write-Host "2. Executando teste..." -ForegroundColor Yellow
ssh $SERVER "/root/testar_endpoint.sh"

Write-Host ""
Write-Host "3. Verificando logs..." -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 20 --no-pager | grep -E '(send-message|Recebida|Enviando|Mensagem|Telegram|SUCESSO|ERRO)'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
