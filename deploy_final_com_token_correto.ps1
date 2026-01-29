# =========================================
# DEPLOY FINAL - TOKEN CORRETO + WEBHOOK
# =========================================

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host " DEPLOY FINAL COM TOKEN CORRETO" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$SSHUser = "root"
$SSHHost = "212.85.0.249"
$SupabasePath = "/root/supabase"

# =========================================
# ETAPA 1: PREPARAR .ENV LOCALMENTE
# =========================================

Write-Host "ETAPA 1/4: Preparando arquivos .env..." -ForegroundColor Cyan

Copy-Item "supabase\functions\telegram-webhook\env_file.txt" "supabase\functions\telegram-webhook\.env" -Force
Copy-Item "supabase\functions\telegram-send\env_file.txt" "supabase\functions\telegram-send\.env" -Force

Write-Host "OK - Arquivos .env preparados!" -ForegroundColor Green
Write-Host ""

# =========================================
# ETAPA 2: COPIAR .ENV PARA SERVIDOR
# =========================================

Write-Host "ETAPA 2/4: Copiando .env para servidor..." -ForegroundColor Cyan

scp "supabase\functions\telegram-webhook\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"
scp "supabase\functions\telegram-send\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"

Write-Host "OK - Arquivos copiados!" -ForegroundColor Green
Write-Host ""

# =========================================
# ETAPA 3: REINICIAR CONTAINER
# =========================================

Write-Host "ETAPA 3/4: Reiniciando container..." -ForegroundColor Cyan

ssh ${SSHUser}@${SSHHost} "cd ${SupabasePath}; docker-compose restart edge-functions; sleep 3"

Write-Host "OK - Container reiniciado!" -ForegroundColor Green
Write-Host ""

# =========================================
# ETAPA 4: CONFIGURAR WEBHOOK
# =========================================

Write-Host "ETAPA 4/4: Configurando webhook..." -ForegroundColor Cyan
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

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -ContentType "application/json"
    
    if ($response.ok) {
        Write-Host "SUCESSO! Webhook configurado!" -ForegroundColor Green
        Write-Host "URL: $WEBHOOK_URL" -ForegroundColor White
    } else {
        Write-Host "ERRO: $($response.description)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERRO: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Verificar webhook
Write-Host "Verificando webhook..." -ForegroundColor Yellow
$apiUrl = "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    Write-Host "URL: $($response.result.url)" -ForegroundColor White
    Write-Host "Pending updates: $($response.result.pending_update_count)" -ForegroundColor White
    
    if ($response.result.last_error_date) {
        Write-Host "Ultimo erro: $($response.result.last_error_message)" -ForegroundColor Red
    } else {
        Write-Host "Status: OK!" -ForegroundColor Green
    }
} catch {
    Write-Host "Erro ao verificar: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host " DEPLOY COMPLETO!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMO PASSO:" -ForegroundColor Cyan
Write-Host "Executar migration SQL no Supabase Studio" -ForegroundColor White
Write-Host "https://212.85.0.249" -ForegroundColor Gray
Write-Host "Arquivo: supabase\migrations\20260124_telegram_integration.sql" -ForegroundColor Gray
Write-Host ""
