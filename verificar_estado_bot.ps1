# ============================================
# VERIFICAR ESTADO DO BOT E WEBHOOK
# ============================================

$BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICANDO BOT E WEBHOOK" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Info do bot
Write-Host "1. Informacoes do bot..." -ForegroundColor Yellow
$botInfo = Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/getMe"
if ($botInfo.ok) {
    Write-Host "   Username: @$($botInfo.result.username)" -ForegroundColor Green
    Write-Host "   Nome: $($botInfo.result.first_name)" -ForegroundColor Gray
}

# 2. Webhook atual
Write-Host ""
Write-Host "2. Webhook configurado..." -ForegroundColor Yellow
$webhookInfo = Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"
if ($webhookInfo.result.url) {
    Write-Host "   URL: $($webhookInfo.result.url)" -ForegroundColor Yellow
    Write-Host "   Pending: $($webhookInfo.result.pending_update_count)" -ForegroundColor Gray
    if ($webhookInfo.result.last_error_message) {
        Write-Host "   ERRO: $($webhookInfo.result.last_error_message)" -ForegroundColor Red
        Write-Host "   Data: $($webhookInfo.result.last_error_date)" -ForegroundColor Red
    }
} else {
    Write-Host "   Nenhum webhook configurado" -ForegroundColor Gray
}

# 3. Updates pendentes
Write-Host ""
Write-Host "3. Mensagens pendentes..." -ForegroundColor Yellow
$updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/getUpdates"
Write-Host "   Updates: $($updates.result.Count)" -ForegroundColor Gray

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICO:" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $webhookInfo.result.url) {
    Write-Host "O bot NAO TEM webhook configurado." -ForegroundColor Yellow
    Write-Host "Por isso nao responde mensagens." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "OPCOES:" -ForegroundColor Cyan
    Write-Host "  1. Configurar webhook (precisa Edge Functions)" -ForegroundColor White
    Write-Host "  2. Usar servidor webhook separado (mais simples)" -ForegroundColor White
    Write-Host "  3. Pausar integracao Telegram por enquanto" -ForegroundColor White
} else {
    Write-Host "Webhook configurado em:" -ForegroundColor Green
    Write-Host "  $($webhookInfo.result.url)" -ForegroundColor White
    Write-Host ""
    if ($webhookInfo.result.last_error_message) {
        Write-Host "MAS esta com erro:" -ForegroundColor Red
        Write-Host "  $($webhookInfo.result.last_error_message)" -ForegroundColor White
    }
}

Write-Host ""
