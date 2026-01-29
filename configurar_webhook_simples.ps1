# =========================================
# CONFIGURAR WEBHOOK DO TELEGRAM
# =========================================

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host " CONFIGURAR WEBHOOK TELEGRAM" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Carregar variaveis do arquivo telegram_env_vars.txt ou usar valores padrao
$TELEGRAM_BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
$TELEGRAM_WEBHOOK_SECRET = "Tg0h00k`$ecr3t!2025fasKFlo4#"
$WEBHOOK_URL = "https://212.85.0.249/functions/v1/telegram-webhook"

Write-Host "Bot Token: $($TELEGRAM_BOT_TOKEN.Substring(0,20))..." -ForegroundColor Gray
Write-Host "Webhook URL: $WEBHOOK_URL" -ForegroundColor Gray
Write-Host "Secret: $($TELEGRAM_WEBHOOK_SECRET.Substring(0,10))..." -ForegroundColor Gray
Write-Host ""

# =========================================
# CONFIGURAR WEBHOOK
# =========================================

Write-Host "Configurando webhook..." -ForegroundColor Yellow
Write-Host ""

$apiUrl = "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook"

$body = @{
    url = $WEBHOOK_URL
    secret_token = $TELEGRAM_WEBHOOK_SECRET
    allowed_updates = @("message", "edited_message", "callback_query")
    drop_pending_updates = $true
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -ContentType "application/json"
    
    if ($response.ok) {
        Write-Host "SUCESSO! Webhook configurado!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Detalhes:" -ForegroundColor Cyan
        Write-Host ($response | ConvertTo-Json -Depth 3)
    } else {
        Write-Host "ERRO ao configurar webhook:" -ForegroundColor Red
        Write-Host ($response | ConvertTo-Json -Depth 3)
    }
} catch {
    Write-Host "ERRO na requisicao: $_" -ForegroundColor Red
}

Write-Host ""

# =========================================
# VERIFICAR WEBHOOK
# =========================================

Write-Host "Verificando status do webhook..." -ForegroundColor Yellow
Write-Host ""

$apiUrl = "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    
    Write-Host "Status do webhook:" -ForegroundColor Cyan
    Write-Host "URL: $($response.result.url)" -ForegroundColor White
    Write-Host "Pending updates: $($response.result.pending_update_count)" -ForegroundColor White
    
    if ($response.result.last_error_date) {
        Write-Host "Ultimo erro: $($response.result.last_error_message)" -ForegroundColor Yellow
    } else {
        Write-Host "Sem erros!" -ForegroundColor Green
    }
} catch {
    Write-Host "ERRO ao verificar webhook: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host " WEBHOOK CONFIGURADO!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMO PASSO:" -ForegroundColor Cyan
Write-Host "Executar migration SQL no Supabase Studio" -ForegroundColor White
Write-Host "https://212.85.0.249" -ForegroundColor Gray
Write-Host ""
