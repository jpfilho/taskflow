# ============================================
# VERIFICAR WEBHOOK DO TELEGRAM - DIAGNÓSTICO COMPLETO
# ============================================

$BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
$WEBHOOK_SECRET = "TgWebhook2026Taskflow_Secret"
$WEBHOOK_URL = "https://api.taskflowv3.com.br/telegram-webhook"
$SERVER = "root@212.85.0.249"
$DOMAIN = "api.taskflowv3.com.br"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DIAGNÓSTICO WEBHOOK TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar webhook no Telegram
Write-Host "1. Verificando webhook no Telegram..." -ForegroundColor Yellow
try {
    $getWebhookUrl = "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"
    $webhookInfo = Invoke-RestMethod -Uri $getWebhookUrl -Method Get
    
    if ($webhookInfo.ok) {
        Write-Host "   [OK] Webhook configurado no Telegram" -ForegroundColor Green
        Write-Host "   URL: $($webhookInfo.result.url)" -ForegroundColor Gray
        Write-Host "   Pending updates: $($webhookInfo.result.pending_update_count)" -ForegroundColor Gray
        
        if ($webhookInfo.result.url -ne $WEBHOOK_URL) {
            Write-Host "   [ATENÇÃO] URL diferente do esperado!" -ForegroundColor Yellow
            Write-Host "   Esperado: $WEBHOOK_URL" -ForegroundColor Gray
            Write-Host "   Atual: $($webhookInfo.result.url)" -ForegroundColor Gray
        } else {
            Write-Host "   [OK] URL está correta!" -ForegroundColor Green
        }
        
        if ($webhookInfo.result.last_error_message) {
            Write-Host "   [ERRO] Último erro do Telegram:" -ForegroundColor Red
            Write-Host "   $($webhookInfo.result.last_error_message)" -ForegroundColor Red
            Write-Host "   Data: $($webhookInfo.result.last_error_date)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   [ERRO] Não foi possível obter informações do webhook" -ForegroundColor Red
    }
} catch {
    Write-Host "   [ERRO] Erro ao verificar webhook: $_" -ForegroundColor Red
}

Write-Host ""

# 2. Verificar Nginx (location /telegram-webhook)
Write-Host "2. Verificando Nginx (location /telegram-webhook)..." -ForegroundColor Yellow
Write-Host "   Executando no servidor..." -ForegroundColor Gray

$nginxCheck = "grep -A 10 'location /telegram-webhook' /etc/nginx/sites-enabled/supabase"
try {
    $nginxResult = ssh $SERVER $nginxCheck 2>&1
    if ($nginxResult -match "location /telegram-webhook") {
        Write-Host "   [OK] Location /telegram-webhook encontrado no Nginx" -ForegroundColor Green
        Write-Host "   Configuração:" -ForegroundColor Gray
        $nginxResult | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    } else {
        Write-Host "   [ERRO] Location /telegram-webhook NÃO encontrado no Nginx!" -ForegroundColor Red
        Write-Host "   É necessário adicionar no /etc/nginx/sites-enabled/supabase" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERRO] Não foi possível verificar Nginx: $_" -ForegroundColor Red
    Write-Host "   Execute manualmente: ssh $SERVER '$nginxCheck'" -ForegroundColor Gray
}

Write-Host ""

# 3. Verificar se Node.js está rodando
Write-Host "3. Verificando serviço Node.js..." -ForegroundColor Yellow
Write-Host "   Executando no servidor..." -ForegroundColor Gray

try {
    $serviceStatus = ssh $SERVER "systemctl is-active telegram-webhook" 2>&1
    if ($serviceStatus -match "active") {
        Write-Host "   [OK] Serviço telegram-webhook está ativo" -ForegroundColor Green
    } else {
        Write-Host "   [ERRO] Serviço telegram-webhook NÃO está ativo!" -ForegroundColor Red
        Write-Host "   Status: $serviceStatus" -ForegroundColor Gray
    }
} catch {
    Write-Host "   [ERRO] Não foi possível verificar serviço: $_" -ForegroundColor Red
}

Write-Host ""

# 4. Verificar logs recentes (últimas 20 linhas)
Write-Host "4. Verificando logs recentes do Node.js..." -ForegroundColor Yellow
Write-Host "   Executando no servidor..." -ForegroundColor Gray

try {
    $logs = ssh $SERVER "journalctl -u telegram-webhook -n 20 --no-pager | grep -E '(Update recebido|telegram-webhook|ERRO|ERROR)'" 2>&1
    if ($logs) {
        Write-Host "   Logs relevantes:" -ForegroundColor Gray
        $logs | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
        
        if ($logs -match "Update recebido") {
            Write-Host "   [OK] Logs mostram recebimento de updates!" -ForegroundColor Green
        } else {
            Write-Host "   [ATENÇÃO] Nenhum 'Update recebido' nos logs recentes" -ForegroundColor Yellow
            Write-Host "   Isso indica que o Telegram não está enviando webhooks" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   [ATENÇÃO] Nenhum log relevante encontrado" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERRO] Não foi possível verificar logs: $_" -ForegroundColor Red
}

Write-Host ""

# 5. Testar endpoint /telegram-webhook via HTTPS
Write-Host "5. Testando endpoint /telegram-webhook via HTTPS..." -ForegroundColor Yellow
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $testBody = @{
        update_id = 999999
        message = @{
            message_id = 1
            from = @{
                id = 123456789
                first_name = "Teste"
            }
            chat = @{
                id = -1001234567890
                type = "supergroup"
            }
            date = [int](Get-Date -UFormat %s)
            text = "Teste de webhook"
        }
    } | ConvertTo-Json -Depth 10
    
    $response = Invoke-WebRequest -Uri "$WEBHOOK_URL" -Method POST `
        -Headers @{"x-telegram-bot-api-secret-token" = $WEBHOOK_SECRET} `
        -Body $testBody -ContentType "application/json" `
        -TimeoutSec 10 -ErrorAction Stop
    
    Write-Host "   [OK] Endpoint respondeu! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Resposta: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "   [ERRO] Endpoint não respondeu: $_" -ForegroundColor Red
    if ($_.Exception.Message -match "certificate|SSL|TLS") {
        Write-Host "   Erro de certificado SSL" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "timeout") {
        Write-Host "   Timeout - servidor pode estar lento" -ForegroundColor Yellow
    } elseif ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "   Status code: $statusCode" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RESUMO E PRÓXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se o webhook não está funcionando:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Configure o webhook no Telegram:" -ForegroundColor Yellow
Write-Host "   .\configurar_webhook_nodejs.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Verifique se Nginx tem location /telegram-webhook:" -ForegroundColor Yellow
Write-Host "   ssh $SERVER 'grep -A 10 location.*telegram-webhook /etc/nginx/sites-enabled/supabase'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Monitore logs em tempo real:" -ForegroundColor Yellow
Write-Host "   ssh $SERVER 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Envie uma mensagem no Telegram e verifique se aparece 'Update recebido'" -ForegroundColor Yellow
Write-Host ""
