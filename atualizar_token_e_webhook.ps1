# =========================================
# ATUALIZAR TOKEN E CONFIGURAR WEBHOOK
# =========================================

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host " ATUALIZAR TOKEN + WEBHOOK" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$SSHUser = "root"
$SSHHost = "212.85.0.249"
$SupabasePath = "/root/supabase"

# =========================================
# ATUALIZAR ARQUIVOS .ENV NO SERVIDOR
# =========================================

Write-Host "Atualizando arquivos .env no servidor..." -ForegroundColor Cyan
Write-Host ""

# Preparar .env localmente
Copy-Item "supabase\functions\telegram-webhook\env_file.txt" "supabase\functions\telegram-webhook\.env" -Force
Copy-Item "supabase\functions\telegram-send\env_file.txt" "supabase\functions\telegram-send\.env" -Force

# Copiar para servidor
Write-Host "  Copiando .env atualizado..." -ForegroundColor Gray
scp "supabase\functions\telegram-webhook\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"
scp "supabase\functions\telegram-send\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"

Write-Host ""
Write-Host "OK - Arquivos .env atualizados!" -ForegroundColor Green
Write-Host ""

# =========================================
# REINICIAR CONTAINER
# =========================================

Write-Host "Reiniciando container..." -ForegroundColor Cyan

ssh ${SSHUser}@${SSHHost} "cd ${SupabasePath}; docker-compose restart edge-functions; sleep 3"

Write-Host "OK - Container reiniciado!" -ForegroundColor Green
Write-Host ""

# =========================================
# CONFIGURAR WEBHOOK
# =========================================

Write-Host "Configurando webhook do Telegram..." -ForegroundColor Cyan
Write-Host ""

$TELEGRAM_BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
$TELEGRAM_WEBHOOK_SECRET = "Tg0h00k`$ecr3t!2025fasKFlo4#"
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
        Write-Host ""
        Write-Host "URL: $WEBHOOK_URL" -ForegroundColor White
    } else {
        Write-Host "ERRO: $($response.description)" -ForegroundColor Red
    }
} catch {
    Write-Host "ERRO: $_" -ForegroundColor Red
}

Write-Host ""

# =========================================
# VERIFICAR WEBHOOK
# =========================================

Write-Host "Verificando webhook..." -ForegroundColor Cyan

$apiUrl = "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    
    Write-Host "URL configurada: $($response.result.url)" -ForegroundColor White
    Write-Host "Pending updates: $($response.result.pending_update_count)" -ForegroundColor White
    
    if ($response.result.last_error_date) {
        Write-Host "Ultimo erro: $($response.result.last_error_message)" -ForegroundColor Yellow
    } else {
        Write-Host "Status: OK - Sem erros!" -ForegroundColor Green
    }
} catch {
    Write-Host "ERRO: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host " CONCLUIDO!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
