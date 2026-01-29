# =========================================
# CONFIGURAR VARIÁVEIS DE AMBIENTE TELEGRAM
# =========================================
# Para Supabase Self-Hosted (Windows)
# Execute: .\configurar_telegram_env.ps1

Write-Host "🔧 Configurando variáveis de ambiente para Telegram..." -ForegroundColor Cyan
Write-Host ""

# =========================================
# 1. CONFIGURAR VARIÁVEIS
# =========================================

$SUPABASE_URL = "https://212.85.0.249"
$TELEGRAM_BOT_TOKEN = "8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec"

# Service Role Key do Supabase (obtida do servidor)
$SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjU4MTc5ODMsImV4cCI6MjA4MTE3Nzk4M30.MYcuHsPkBgYg_M1WVHKbtO3MQYalYNYOppr0Q3ynUgw"

# Gerar senha segura para webhook secret
$randomBytes = New-Object byte[] 8
(New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($randomBytes)
$randomHex = [BitConverter]::ToString($randomBytes).Replace("-", "").ToLower()
$TELEGRAM_WEBHOOK_SECRET = "TgWh00k`$ecr3t!2026TaskFlow#$randomHex"

Write-Host "📝 Variáveis configuradas:" -ForegroundColor Green
Write-Host "   SUPABASE_URL: $SUPABASE_URL"
Write-Host "   TELEGRAM_BOT_TOKEN: $($TELEGRAM_BOT_TOKEN.Substring(0,20))..."
Write-Host "   TELEGRAM_WEBHOOK_SECRET: $($TELEGRAM_WEBHOOK_SECRET.Substring(0,20))..."
Write-Host ""

# =========================================
# 2. CRIAR ARQUIVO .env PARA EDGE FUNCTIONS
# =========================================

# Para telegram-webhook
Write-Host "📄 Criando arquivo .env para telegram-webhook..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "supabase\functions\telegram-webhook" | Out-Null

@"
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_WEBHOOK_SECRET=$TELEGRAM_WEBHOOK_SECRET
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
"@ | Out-File -FilePath "supabase\functions\telegram-webhook\.env" -Encoding UTF8

# Para telegram-send
Write-Host "📄 Criando arquivo .env para telegram-send..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "supabase\functions\telegram-send" | Out-Null

@"
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
"@ | Out-File -FilePath "supabase\functions\telegram-send\.env" -Encoding UTF8

Write-Host ""
Write-Host "✅ Arquivos .env criados!" -ForegroundColor Green
Write-Host ""

# =========================================
# 3. CRIAR ARQUIVO COM AS VARIÁVEIS (PARA REFERÊNCIA)
# =========================================

Write-Host "📄 Salvando variáveis em telegram_env_vars.txt (para referência)..." -ForegroundColor Yellow

$webhookCommand = @"
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" ``
  -H "Content-Type: application/json" ``
  -d "{
    \`"url\`": \`"$SUPABASE_URL/functions/v1/telegram-webhook\`",
    \`"secret_token\`": \`"$TELEGRAM_WEBHOOK_SECRET\`",
    \`"allowed_updates\`": [\`"message\`", \`"edited_message\`", \`"callback_query\`"]
  }"
"@

@"
# =========================================
# VARIÁVEIS DE AMBIENTE - TELEGRAM
# =========================================
# Criado em: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# 
# IMPORTANTE: Guarde estas variáveis com segurança!
# Você precisará delas para configurar o webhook.

TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_WEBHOOK_SECRET=$TELEGRAM_WEBHOOK_SECRET
SUPABASE_URL=$SUPABASE_URL

# =========================================
# PRÓXIMOS PASSOS:
# =========================================
# 
# 1. Deploy das Edge Functions:
#    supabase functions deploy telegram-webhook
#    supabase functions deploy telegram-send
# 
# 2. Configurar webhook (copie o comando abaixo):
#    
$webhookCommand
# 
# 3. Verificar webhook:
#    curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"
"@ | Out-File -FilePath "telegram_env_vars.txt" -Encoding UTF8

Write-Host ""
Write-Host "✅ Configuração concluída!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 RESUMO:" -ForegroundColor Cyan
Write-Host "   ✅ Arquivos .env criados em:"
Write-Host "      - supabase\functions\telegram-webhook\.env"
Write-Host "      - supabase\functions\telegram-send\.env"
Write-Host "   ✅ Variáveis salvas em: telegram_env_vars.txt"
Write-Host ""
Write-Host "🚀 PRÓXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣ Deploy das Edge Functions:"
Write-Host "   supabase functions deploy telegram-webhook"
Write-Host "   supabase functions deploy telegram-send"
Write-Host ""
Write-Host "2️⃣ Configurar webhook do Telegram:"
Write-Host "   (abra telegram_env_vars.txt e copie o comando curl)"
Write-Host ""
Write-Host "3️⃣ Verificar webhook:"
Write-Host "   curl `"https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo`""
Write-Host ""

# =========================================
# 4. CRIAR SCRIPT PARA CONFIGURAR WEBHOOK
# =========================================

Write-Host "📄 Criando script configurar_webhook.ps1..." -ForegroundColor Yellow

@'
# Configurar Webhook do Telegram

$ErrorActionPreference = "Stop"

# Ler variáveis do arquivo
if (-not (Test-Path "telegram_env_vars.txt")) {
    Write-Host "❌ Erro: arquivo telegram_env_vars.txt não encontrado" -ForegroundColor Red
    Write-Host "Execute primeiro: .\configurar_telegram_env.ps1"
    exit 1
}

$content = Get-Content "telegram_env_vars.txt" -Raw
$TELEGRAM_BOT_TOKEN = ($content | Select-String -Pattern 'TELEGRAM_BOT_TOKEN=(.+)').Matches.Groups[1].Value
$TELEGRAM_WEBHOOK_SECRET = ($content | Select-String -Pattern 'TELEGRAM_WEBHOOK_SECRET=(.+)').Matches.Groups[1].Value
$SUPABASE_URL = ($content | Select-String -Pattern 'SUPABASE_URL=(.+)').Matches.Groups[1].Value

Write-Host "🔗 Configurando webhook do Telegram..." -ForegroundColor Cyan
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

    Write-Host "📡 Resposta:" -ForegroundColor Yellow
    $response | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host ""

    if ($response.ok) {
        Write-Host "✅ Webhook configurado com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🔍 Verificando webhook..." -ForegroundColor Cyan
        
        $webhookInfo = Invoke-RestMethod `
            -Uri "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo" `
            -Method Get
        
        $webhookInfo.result | ConvertTo-Json -Depth 10 | Write-Host
    } else {
        Write-Host "❌ Erro ao configurar webhook" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erro: $_" -ForegroundColor Red
}
'@ | Out-File -FilePath "configurar_webhook.ps1" -Encoding UTF8

Write-Host "✅ Script configurar_webhook.ps1 criado!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 DICA: Para configurar o webhook, execute:" -ForegroundColor Cyan
Write-Host "   .\configurar_webhook.ps1"
Write-Host ""
