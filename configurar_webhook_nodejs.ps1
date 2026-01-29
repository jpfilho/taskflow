# ============================================
# CONFIGURAR WEBHOOK DO TELEGRAM PARA NODE.JS
# ============================================
# Este script configura o webhook do Telegram para apontar
# para o Node.js rodando na VPS (via Nginx)

$BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
$WEBHOOK_SECRET = "TgWebhook2026Taskflow_Secret"
$WEBHOOK_URL = "https://api.taskflowv3.com.br/telegram-webhook"  # Node.js via Nginx

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CONFIGURAR WEBHOOK DO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bot Token: $($BOT_TOKEN.Substring(0,10))..." -ForegroundColor Gray
Write-Host "Webhook URL: $WEBHOOK_URL" -ForegroundColor Gray
Write-Host "Secret: $WEBHOOK_SECRET" -ForegroundColor Gray
Write-Host ""
Write-Host "NOTA: Este webhook aponta para o Node.js na VPS" -ForegroundColor Yellow
Write-Host "      (não para Edge Functions do Supabase)" -ForegroundColor Yellow
Write-Host ""

# 1. Verificar webhook atual
Write-Host "1. Verificando webhook atual..." -ForegroundColor Yellow
try {
    $getWebhookUrl = "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"
    $currentWebhook = Invoke-RestMethod -Uri $getWebhookUrl -Method Get
    
    if ($currentWebhook.ok) {
        Write-Host "   Webhook atual:" -ForegroundColor Gray
        Write-Host "   URL: $($currentWebhook.result.url)" -ForegroundColor Gray
        Write-Host "   Pending updates: $($currentWebhook.result.pending_update_count)" -ForegroundColor Gray
        Write-Host "   Last error: $($currentWebhook.result.last_error_message)" -ForegroundColor $(if ($currentWebhook.result.last_error_message) { "Red" } else { "Green" })
        
        if ($currentWebhook.result.url -eq $WEBHOOK_URL) {
            Write-Host "   [OK] Webhook já está configurado corretamente!" -ForegroundColor Green
            Write-Host ""
            Write-Host "   Se mensagens não estão chegando, verifique:" -ForegroundColor Yellow
            Write-Host "   - Nginx tem location /telegram-webhook configurado" -ForegroundColor Gray
            Write-Host "   - Node.js está rodando (journalctl -u telegram-webhook -f)" -ForegroundColor Gray
            Write-Host "   - Logs mostram 'Update recebido'" -ForegroundColor Gray
            exit 0
        } else {
            Write-Host "   [ATENÇÃO] Webhook aponta para URL diferente!" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "   [ERRO] Não foi possível verificar webhook: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host -NoNewline "Configurar webhook para $WEBHOOK_URL? (S/N): " -ForegroundColor Yellow
$confirm = Read-Host

if ($confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Cancelado!" -ForegroundColor Red
    exit
}

# 2. Configurar webhook
Write-Host ""
Write-Host "2. Configurando webhook..." -ForegroundColor Yellow

$setWebhookUrl = "https://api.telegram.org/bot$BOT_TOKEN/setWebhook"
$body = @{
    url = $WEBHOOK_URL
    secret_token = $WEBHOOK_SECRET
    allowed_updates = @("message", "edited_message", "callback_query")
    drop_pending_updates = $true
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $setWebhookUrl -Method Post -Body $body -ContentType "application/json"
    
    if ($response.ok) {
        Write-Host "   [OK] Webhook configurado com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "   Detalhes:" -ForegroundColor Cyan
        Write-Host "   URL: $($response.result.url)" -ForegroundColor Gray
        Write-Host "   Pending updates dropped: $($response.result.pending_update_count)" -ForegroundColor Gray
    } else {
        Write-Host "   [ERRO] Falha ao configurar webhook:" -ForegroundColor Red
        Write-Host ($response | ConvertTo-Json -Depth 3)
        exit 1
    }
} catch {
    Write-Host "   [ERRO] Erro na requisição: $_" -ForegroundColor Red
    exit 1
}

# 3. Verificar novamente
Write-Host ""
Write-Host "3. Verificando webhook configurado..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

try {
    $verifyWebhook = Invoke-RestMethod -Uri $getWebhookUrl -Method Get
    if ($verifyWebhook.ok -and $verifyWebhook.result.url -eq $WEBHOOK_URL) {
        Write-Host "   [OK] Webhook verificado e funcionando!" -ForegroundColor Green
    } else {
        Write-Host "   [ATENÇÃO] Webhook pode não estar correto" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERRO] Não foi possível verificar: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "PRÓXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "1. Verifique se Nginx tem location /telegram-webhook:" -ForegroundColor Yellow
Write-Host "   ssh root@212.85.0.249 'grep -A 5 location.*telegram-webhook /etc/nginx/sites-enabled/supabase'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Monitore logs do Node.js:" -ForegroundColor Yellow
Write-Host "   ssh root@212.85.0.249 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Envie uma mensagem no Telegram e verifique se aparece 'Update recebido' nos logs" -ForegroundColor Yellow
Write-Host ""
