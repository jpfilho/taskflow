# CONFIGURAR WEBHOOK - SEM SSH
Write-Host ""
Write-Host "Configurando webhook..." -ForegroundColor Cyan
Write-Host ""

$TELEGRAM_BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
$TELEGRAM_WEBHOOK_SECRET = "Tg0h00kSecr3t2025fasKFlow"
$WEBHOOK_URL = "https://212.85.0.249/functions/v1/telegram-webhook"

$apiUrl = "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook"
$body = @{
    url = $WEBHOOK_URL
    secret_token = $TELEGRAM_WEBHOOK_SECRET
    allowed_updates = @("message", "edited_message", "callback_query")
    drop_pending_updates = $true
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -ContentType "application/json"

if ($response.ok) {
    Write-Host "SUCESSO! Webhook configurado!" -ForegroundColor Green
    Write-Host "URL: $WEBHOOK_URL" -ForegroundColor White
} else {
    Write-Host "ERRO: $($response.description)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Verificando..." -ForegroundColor Cyan
$response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo" -Method Get
Write-Host "URL: $($response.result.url)" -ForegroundColor White
if ($response.result.last_error_message) {
    Write-Host "Status: $($response.result.last_error_message)" -ForegroundColor Yellow
} else {
    Write-Host "Status: OK - Sem erros!" -ForegroundColor Green
}
Write-Host ""
