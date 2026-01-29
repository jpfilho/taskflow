# ============================================
# VERIFICAÇÃO COMPLETA SERVIDOR NODE.JS TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"
$DOMAIN = "api.taskflowv3.com.br"
$PORT = 3001

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAÇÃO SERVIDOR NODE.JS TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se o serviço está rodando
Write-Host "1. Verificando status do serviço telegram-webhook..." -ForegroundColor Yellow
ssh $SERVER "systemctl status telegram-webhook --no-pager -l | head -15"

Write-Host ""
Write-Host "2. Verificando se o processo Node.js está rodando..." -ForegroundColor Yellow
ssh $SERVER "ps aux | grep -E 'node.*telegram-webhook|node.*3001' | grep -v grep"

Write-Host ""
Write-Host "3. Verificando porta $PORT..." -ForegroundColor Yellow
ssh $SERVER "netstat -tlnp | grep $PORT || ss -tlnp | grep $PORT"

Write-Host ""
Write-Host "4. Testando endpoint localmente no servidor..." -ForegroundColor Yellow
ssh $SERVER @"
curl -X POST http://127.0.0.1:$PORT/send-message \
  -H 'Content-Type: application/json' \
  -d '{"mensagem_id":"test-verificacao","thread_type":"TASK","thread_id":"test"}' \
  -w "\nHTTP Status: %{http_code}\n" \
  2>&1
"@

Write-Host ""
Write-Host "5. Verificando logs recentes do serviço..." -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 30 --no-pager | tail -20"

Write-Host ""
Write-Host "6. Verificando configuração Nginx para /send-message..." -ForegroundColor Yellow
ssh $SERVER "grep -A 15 'location /send-message' /etc/nginx/sites-enabled/* 2>/dev/null || echo 'Configuração não encontrada'"

Write-Host ""
Write-Host "7. Verificando se Nginx está rodando..." -ForegroundColor Yellow
ssh $SERVER "systemctl status nginx --no-pager | head -10"

Write-Host ""
Write-Host "8. Testando DNS..." -ForegroundColor Yellow
try {
    $dns = Resolve-DnsName -Name $DOMAIN -ErrorAction Stop
    Write-Host "   ✅ DNS resolvido: $($dns[0].IPAddress)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Erro ao resolver DNS: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "9. Testando endpoint via HTTPS (domínio)..." -ForegroundColor Yellow
try {
    $body = @{
        mensagem_id = "test-https"
        thread_type = "TASK"
        thread_id = "test"
    } | ConvertTo-Json
    
    # Ignorar certificado SSL para teste
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    
    $response = Invoke-WebRequest -Uri "https://$DOMAIN/send-message" `
        -Method POST `
        -Body $body `
        -ContentType "application/json" `
        -TimeoutSec 10 `
        -ErrorAction Stop
    
    Write-Host "   ✅ Endpoint acessível! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Resposta: $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Erro: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "10. Verificando arquivo do servidor..." -ForegroundColor Yellow
ssh $SERVER "ls -lh /root/telegram-webhook/telegram-webhook-server*.js 2>/dev/null || echo 'Arquivo não encontrado'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RESUMO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se o serviço não estiver rodando, execute:" -ForegroundColor Yellow
Write-Host "  ssh $SERVER 'systemctl start telegram-webhook'" -ForegroundColor White
Write-Host ""
Write-Host "Se precisar reiniciar:" -ForegroundColor Yellow
Write-Host "  ssh $SERVER 'systemctl restart telegram-webhook'" -ForegroundColor White
Write-Host ""
Write-Host "Para ver logs em tempo real:" -ForegroundColor Yellow
Write-Host "  ssh $SERVER 'journalctl -u telegram-webhook -f'" -ForegroundColor White
Write-Host ""
