# ============================================
# TESTAR WEBHOOK DO TELEGRAM
# ============================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TESTAR WEBHOOK DO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar info do webhook
Write-Host "1. Verificando configuracao do webhook..." -ForegroundColor Yellow
$webhookUrl = "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"
$info = Invoke-RestMethod -Uri $webhookUrl -Method Get

Write-Host "   URL: $($info.result.url)" -ForegroundColor White
Write-Host "   Updates pendentes: $($info.result.pending_update_count)" -ForegroundColor White
if ($info.result.last_error_date) {
    Write-Host "   Ultimo erro: $($info.result.last_error_message)" -ForegroundColor Red
} else {
    Write-Host "   Sem erros!" -ForegroundColor Green
}

# 2. Verificar status do servico
Write-Host ""
Write-Host "2. Verificando status do servico..." -ForegroundColor Yellow
ssh root@212.85.0.249 "systemctl is-active telegram-webhook && echo '   Servico ATIVO' || echo '   Servico INATIVO'"

# 3. Verificar ultimos logs
Write-Host ""
Write-Host "3. Ultimos logs do servico:" -ForegroundColor Yellow
ssh root@212.85.0.249 "journalctl -u telegram-webhook -n 10 --no-pager"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "TESTE MANUAL" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora envie uma mensagem no grupo do Telegram!" -ForegroundColor Yellow
Write-Host "Depois execute novamente este script para ver os logs." -ForegroundColor White
Write-Host ""
