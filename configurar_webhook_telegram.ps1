# ============================================
# CONFIGURAR WEBHOOK DO TELEGRAM
# ============================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CONFIGURAR WEBHOOK DO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Solicitar informacoes
Write-Host "Digite o TOKEN do bot do Telegram:" -ForegroundColor Yellow
Write-Host "(Exemplo: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz)" -ForegroundColor Gray
$BOT_TOKEN = Read-Host "Token"

Write-Host ""
Write-Host "Digite um SECRET para o webhook (senha segura):" -ForegroundColor Yellow
Write-Host "(Use apenas letras, numeros, - e _)" -ForegroundColor Gray
$WEBHOOK_SECRET = Read-Host "Secret"

Write-Host ""
Write-Host "Digite o CHAT_ID do grupo/supergrupo onde o bot esta:" -ForegroundColor Yellow
Write-Host "(Exemplo: -1001234567890)" -ForegroundColor Gray
$CHAT_ID = Read-Host "Chat ID"

$WEBHOOK_URL = "https://api.taskflowv3.com.br/functions/v1/telegram-webhook"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RESUMO DA CONFIGURACAO:" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Bot Token: $($BOT_TOKEN.Substring(0,10))..." -ForegroundColor Gray
Write-Host "Webhook URL: $WEBHOOK_URL" -ForegroundColor Gray
Write-Host "Secret: $($WEBHOOK_SECRET.Substring(0,5))..." -ForegroundColor Gray
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
Write-Host "1. Configurando webhook no Telegram..." -ForegroundColor Yellow

$setWebhookUrl = "https://api.telegram.org/bot$BOT_TOKEN/setWebhook"
$body = @{
    url = $WEBHOOK_URL
    secret_token = $WEBHOOK_SECRET
    max_connections = 40
    allowed_updates = @("message", "callback_query")
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $setWebhookUrl -Method Post -Body $body -ContentType "application/json"
    
    if ($response.ok) {
        Write-Host "   Webhook configurado com sucesso!" -ForegroundColor Green
        Write-Host "   Descricao: $($response.description)" -ForegroundColor Gray
    } else {
        Write-Host "   ERRO ao configurar webhook!" -ForegroundColor Red
        Write-Host "   $($response.description)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ERRO ao conectar com Telegram!" -ForegroundColor Red
    Write-Host "   $_" -ForegroundColor Red
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
    Write-Host "   Ultimo erro: $($webhookInfo.result.last_error_message)" -ForegroundColor Red
}

# 3. Salvar variaveis de ambiente
Write-Host ""
Write-Host "3. Salvando variaveis de ambiente..." -ForegroundColor Yellow

$envContent = @"
# TELEGRAM CONFIGURATION
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_WEBHOOK_SECRET=$WEBHOOK_SECRET
TELEGRAM_CHAT_ID=$CHAT_ID
"@

$envContent | Out-File -FilePath "telegram_env.txt" -Encoding UTF8
Write-Host "   Salvo em: telegram_env.txt" -ForegroundColor Gray

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "WEBHOOK CONFIGURADO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMO PASSO:" -ForegroundColor Yellow
Write-Host "   1. Configure as variaveis de ambiente no Supabase" -ForegroundColor White
Write-Host "   2. Deploy das Edge Functions (telegram-webhook)" -ForegroundColor White
Write-Host ""
Write-Host "Arquivo com as variaveis: telegram_env.txt" -ForegroundColor Cyan
Write-Host ""
