# ============================================
# ATUALIZAR CHAT ID DAS SUBSCRIPTIONS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ATUALIZAR CHAT ID" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "PROBLEMA IDENTIFICADO:" -ForegroundColor Yellow
Write-Host "  O grupo foi migrado para supergrupo!" -ForegroundColor White
Write-Host "  Chat ID antigo: -5127731041" -ForegroundColor Gray
Write-Host "  Chat ID novo: -1003721115749" -ForegroundColor Green
Write-Host ""

Write-Host "Atualizando subscriptions..." -ForegroundColor Yellow
scp atualizar_chat_id.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/atualizar_chat_id.sh && /root/atualizar_chat_id.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CHAT ID ATUALIZADO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "AGORA TESTE:" -ForegroundColor Yellow
Write-Host "  1. Execute: .\testar_endpoint_simples.ps1" -ForegroundColor White
Write-Host "  2. OU envie uma mensagem no Flutter" -ForegroundColor White
Write-Host "  3. Verifique se aparece no Telegram!" -ForegroundColor White
Write-Host ""
