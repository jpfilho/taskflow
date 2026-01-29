# Configurar Webhook do Telegram

$ErrorActionPreference = "Stop"

# Ler variÃ¡veis do arquivo
if (-not (Test-Path "telegram_env_vars.txt")) {
    Write-Host "âŒ Erro: arquivo telegram_env_vars.txt nÃ£o encontrado" -ForegroundColor Red
    Write-Host "Execute primeiro: .\configurar_telegram_env.ps1"
    exit 1
}

$content = Get-Content "telegram_env_vars.txt" -Raw
$TELEGRAM_BOT_TOKEN = ($content | Select-String -Pattern 'TELEGRAM_BOT_TOKEN=(.+)').Matches.Groups[1].Value
$TELEGRAM_WEBHOOK_SECRET = ($content | Select-String -Pattern 'TELEGRAM_WEBHOOK_SECRET=(.+)').Matches.Groups[1].Value
$SUPABASE_URL = ($content | Select-String -Pattern 'SUPABASE_URL=(.+)').Matches.Groups[1].Value

Write-Host "ðŸ”— Configurando webhook do Telegram..." -ForegroundColor Cyan
Write-Host ""

$body = @{
    url = "$SUPABASE_URL/functions/v1/telegram-webhook"
    secret_token = $TELEGRAM_WEBHOOK_SECRET
    allowed_updates = @("message", "edited_message", "callback_query")
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod `
        -Uri "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    Write-Host "ðŸ“¡ Resposta:" -ForegroundColor Yellow
    $response | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host ""

    if ($response.ok) {
        Write-Host "âœ… Webhook configurado com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "ðŸ” Verificando webhook..." -ForegroundColor Cyan
        
        $webhookInfo = Invoke-RestMethod `
            -Uri "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo" `
            -Method Get
        
        $webhookInfo.result | ConvertTo-Json -Depth 10 | Write-Host
    } else {
        Write-Host "âŒ Erro ao configurar webhook" -ForegroundColor Red
    }
} catch {
    Write-Host "âŒ Erro: $_" -ForegroundColor Red
}
