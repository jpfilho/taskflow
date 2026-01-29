# ============================================
# CONFIGURAR WEBHOOK - VERSAO CORRIGIDA
# ============================================
# Com secret validado para o Telegram

$BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
$WEBHOOK_SECRET = "TgWebhook2026Taskflow_Secret"  # SEM caracteres especiais
$WEBHOOK_URL = "https://api.taskflowv3.com.br/functions/v1/telegram-webhook"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CONFIGURAR WEBHOOK DO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Bot: @taskflow_bot" -ForegroundColor Gray
Write-Host "Webhook URL: $WEBHOOK_URL" -ForegroundColor Gray
Write-Host "Secret: $WEBHOOK_SECRET" -ForegroundColor Gray
Write-Host ""

# Pedir Chat ID
Write-Host "Digite o CHAT_ID do grupo (ex: -1001234567890):" -ForegroundColor Yellow
Write-Host "(Se ainda nao tem, execute: .\obter_chat_id_rapido.ps1)" -ForegroundColor Gray
$CHAT_ID = Read-Host "Chat ID"

if (-not $CHAT_ID -or $CHAT_ID -eq "") {
    Write-Host "Chat ID nao pode ser vazio!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RESUMO:" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Bot Token: $($BOT_TOKEN.Substring(0,10))..." -ForegroundColor Gray
Write-Host "Webhook URL: $WEBHOOK_URL" -ForegroundColor Gray
Write-Host "Secret: $WEBHOOK_SECRET" -ForegroundColor Gray
Write-Host "Chat ID: $CHAT_ID" -ForegroundColor Gray
Write-Host ""
Write-Host -NoNewline "Continuar? (S/N): " -ForegroundColor Yellow
$confirm = Read-Host

if ($confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Cancelado!" -ForegroundColor Red
    exit
}

# 1. Configurar webhook
Write-Host ""
Write-Host "1. Configurando webhook..." -ForegroundColor Yellow

$setWebhookUrl = "https://api.telegram.org/bot$BOT_TOKEN/setWebhook"
$body = @{
    url = $WEBHOOK_URL
    secret_token = $WEBHOOK_SECRET
    max_connections = 40
    allowed_updates = @("message", "edited_message", "callback_query")
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $setWebhookUrl -Method Post -Body $body -ContentType "application/json"
    
    if ($response.ok) {
        Write-Host "   Webhook configurado!" -ForegroundColor Green
        Write-Host "   $($response.description)" -ForegroundColor Gray
    } else {
        Write-Host "   ERRO: $($response.description)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ERRO ao conectar: $_" -ForegroundColor Red
    exit 1
}

# 2. Verificar webhook
Write-Host ""
Write-Host "2. Verificando webhook..." -ForegroundColor Yellow

$getWebhookUrl = "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"
$webhookInfo = Invoke-RestMethod -Uri $getWebhookUrl

Write-Host "   URL: $($webhookInfo.result.url)" -ForegroundColor Gray
Write-Host "   Pending updates: $($webhookInfo.result.pending_update_count)" -ForegroundColor Gray
if ($webhookInfo.result.last_error_message) {
    Write-Host "   Ultimo erro: $($webhookInfo.result.last_error_message)" -ForegroundColor Yellow
}

# 3. Salvar configuracao
Write-Host ""
Write-Host "3. Salvando configuracao..." -ForegroundColor Yellow

$config = @"
# CONFIGURACAO TELEGRAM - TASKFLOW
# Gerado em: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

BOT_TOKEN=$BOT_TOKEN
WEBHOOK_SECRET=$WEBHOOK_SECRET
WEBHOOK_URL=$WEBHOOK_URL
CHAT_ID=$CHAT_ID

# Supabase
SUPABASE_URL=http://212.85.0.249:8000
SUPABASE_URL_HTTPS=https://api.taskflowv3.com.br
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw
"@

$config | Out-File -FilePath "telegram_config_final.txt" -Encoding UTF8
Write-Host "   Salvo em: telegram_config_final.txt" -ForegroundColor Gray

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "WEBHOOK CONFIGURADO COM SUCESSO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMO PASSO:" -ForegroundColor Yellow
Write-Host "   Configurar variaveis de ambiente no servidor" -ForegroundColor White
Write-Host "   e fazer deploy das Edge Functions" -ForegroundColor White
Write-Host ""
Write-Host "Arquivo com as variaveis: telegram_config_final.txt" -ForegroundColor Cyan
Write-Host ""
