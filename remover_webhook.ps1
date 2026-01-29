# ============================================
# REMOVER WEBHOOK DO TELEGRAM
# ============================================

$BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "REMOVENDO WEBHOOK DO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Removendo webhook..." -ForegroundColor Yellow

try {
    $url = "https://api.telegram.org/bot$BOT_TOKEN/deleteWebhook"
    $response = Invoke-RestMethod -Uri $url -Method Post
    
    if ($response.ok) {
        Write-Host "   Webhook removido com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "   ERRO: $($response.description)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ERRO: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Verificando status..." -ForegroundColor Yellow
$webhookInfo = Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"

if ($webhookInfo.result.url) {
    Write-Host "   Webhook ainda configurado: $($webhookInfo.result.url)" -ForegroundColor Yellow
} else {
    Write-Host "   Webhook removido completamente!" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "WEBHOOK REMOVIDO" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "O bot agora nao tem webhook configurado." -ForegroundColor White
Write-Host "Ele nao respondera mensagens ate configurar" -ForegroundColor White
Write-Host "um backend funcionando." -ForegroundColor White
Write-Host ""
