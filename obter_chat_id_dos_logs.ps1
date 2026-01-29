# ============================================
# OBTER CHAT ID DOS LOGS DO WEBHOOK
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CHAT ID NOS LOGS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Buscando chat_id nas ultimas mensagens..." -ForegroundColor Yellow
Write-Host ""

ssh $SERVER "journalctl -u telegram-webhook -n 50 --no-pager | grep -E 'chat.*id|message_id'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
