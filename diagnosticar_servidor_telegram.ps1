# ============================================
# DIAGNÓSTICO COMPLETO SERVIDOR TELEGRAM
# ============================================
# Verifica se o servidor Node.js está funcionando

$SERVER_IP = "212.85.0.249"
$DOMAIN = "api.taskflowv3.com.br"
$PORT = 3001

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DIAGNÓSTICO SERVIDOR TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar DNS
Write-Host "1. Verificando resolução DNS..." -ForegroundColor Yellow
try {
    $dnsResult = Resolve-DnsName -Name $DOMAIN -ErrorAction Stop
    Write-Host "   ✅ DNS resolvido: $($dnsResult[0].IPAddress)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Erro ao resolver DNS: $_" -ForegroundColor Red
    Write-Host "   ⚠️  Tentando resolver via IP direto..." -ForegroundColor Yellow
}

# 2. Verificar conectividade com IP direto
Write-Host ""
Write-Host "2. Testando conectividade com IP direto ($SERVER_IP)..." -ForegroundColor Yellow
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connect = $tcpClient.BeginConnect($SERVER_IP, 443, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
    if ($wait) {
        $tcpClient.EndConnect($connect)
        Write-Host "   ✅ IP $SERVER_IP:443 está acessível" -ForegroundColor Green
        $tcpClient.Close()
    } else {
        Write-Host "   ❌ Timeout ao conectar em $SERVER_IP:443" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Erro ao conectar: $_" -ForegroundColor Red
}

# 3. Testar endpoint HTTPS via domínio
Write-Host ""
Write-Host "3. Testando endpoint HTTPS via domínio..." -ForegroundColor Yellow
try {
    $testUrl = "https://$DOMAIN/send-message"
    Write-Host "   URL: $testUrl" -ForegroundColor Gray
    
    $body = @{
        mensagem_id = "test-diagnostico"
        thread_type = "TASK"
        thread_id = "test"
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest -Uri $testUrl -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
    Write-Host "   ✅ Endpoint acessível! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Resposta: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Erro ao acessar endpoint: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    }
}

# 4. Testar endpoint HTTPS via IP direto
Write-Host ""
Write-Host "4. Testando endpoint HTTPS via IP direto..." -ForegroundColor Yellow
try {
    $testUrl = "https://$SERVER_IP/send-message"
    Write-Host "   URL: $testUrl" -ForegroundColor Gray
    
    # Ignorar certificado SSL para teste
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    
    $body = @{
        mensagem_id = "test-diagnostico-ip"
        thread_type = "TASK"
        thread_id = "test"
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest -Uri $testUrl -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
    Write-Host "   ✅ Endpoint via IP acessível! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Resposta: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Erro ao acessar endpoint via IP: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    }
}

# 5. Verificar se o serviço está rodando no servidor (se tiver acesso SSH)
Write-Host ""
Write-Host "5. Verificando status do serviço no servidor..." -ForegroundColor Yellow
Write-Host "   (Execute no servidor: systemctl status telegram-webhook)" -ForegroundColor Gray
Write-Host "   (Ou: ps aux | grep node)" -ForegroundColor Gray

# 6. Verificar logs do servidor
Write-Host ""
Write-Host "6. Comandos para verificar logs:" -ForegroundColor Yellow
Write-Host "   journalctl -u telegram-webhook -n 50 --no-pager" -ForegroundColor Gray
Write-Host "   tail -f /root/telegram-webhook/logs/*.log" -ForegroundColor Gray

# 7. Verificar configuração Nginx
Write-Host ""
Write-Host "7. Verificando configuração Nginx..." -ForegroundColor Yellow
Write-Host "   (Execute no servidor: grep -A 10 'location /send-message' /etc/nginx/sites-available/*)" -ForegroundColor Gray

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DIAGNÓSTICO CONCLUÍDO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
