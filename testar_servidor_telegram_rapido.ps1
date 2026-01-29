# ============================================
# TESTE RÁPIDO SERVIDOR TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"
$DOMAIN = "api.taskflowv3.com.br"

Write-Host "Testando servidor Telegram..." -ForegroundColor Cyan
Write-Host ""

# Teste 1: Serviço está rodando?
Write-Host "1. Verificando servico..." -ForegroundColor Yellow
$serviceStatus = ssh $SERVER "systemctl is-active telegram-webhook 2>&1"
if ($serviceStatus -eq "active") {
    Write-Host "   [OK] Servico esta rodando" -ForegroundColor Green
} else {
    Write-Host "   [ERRO] Servico NAO esta rodando: $serviceStatus" -ForegroundColor Red
    Write-Host "   Execute: ssh $SERVER 'systemctl start telegram-webhook'" -ForegroundColor Yellow
}

# Teste 2: Porta 3001 está aberta?
Write-Host ""
Write-Host "2. Verificando porta 3001..." -ForegroundColor Yellow
$portCheck = ssh $SERVER "netstat -tlnp 2>/dev/null | grep :3001 || ss -tlnp 2>/dev/null | grep :3001"
if ($portCheck) {
    Write-Host "   [OK] Porta 3001 esta aberta" -ForegroundColor Green
    Write-Host "   $portCheck" -ForegroundColor Gray
} else {
    Write-Host "   [ERRO] Porta 3001 NAO esta aberta" -ForegroundColor Red
}

# Teste 3: Endpoint local funciona?
Write-Host ""
Write-Host "3. Testando endpoint local (127.0.0.1:3001)..." -ForegroundColor Yellow
# Criar arquivo temporário com JSON para evitar problemas de escape
$localTest = ssh $SERVER @"
echo '{"mensagem_id":"test","thread_type":"TASK","thread_id":"test"}' > /tmp/test_json.json && \
curl -s -X POST http://127.0.0.1:3001/send-message \
  -H 'Content-Type: application/json' \
  -d @/tmp/test_json.json \
  -w '\nHTTP:%{http_code}' 2>&1 | tail -3 && \
rm -f /tmp/test_json.json
"@
if ($localTest -match "HTTP:200|ok.*true|sent.*true") {
    Write-Host "   [OK] Endpoint local funciona!" -ForegroundColor Green
} else {
    Write-Host "   [ERRO] Endpoint local NAO funciona" -ForegroundColor Red
    Write-Host "   Resposta: $localTest" -ForegroundColor Gray
    if ($localTest -match "JSON inv") {
        Write-Host "   Erro de JSON: O formato pode estar incorreto" -ForegroundColor Yellow
    } elseif ($localTest -match "Par.*metros faltando|404|not found") {
        Write-Host "   Nota: O erro pode ser porque a mensagem 'test' nao existe no banco (esperado)" -ForegroundColor Yellow
    }
}

# Teste 4: DNS resolve?
Write-Host ""
Write-Host "4. Verificando DNS..." -ForegroundColor Yellow
try {
    $dns = Resolve-DnsName -Name $DOMAIN -ErrorAction Stop
    Write-Host "   [OK] DNS resolve: $($dns[0].IPAddress)" -ForegroundColor Green
} catch {
    Write-Host "   [ERRO] DNS NAO resolve: $_" -ForegroundColor Red
    Write-Host "   Problema de DNS ou dominio nao configurado" -ForegroundColor Yellow
}

# Teste 5: Endpoint HTTP direto na porta 3001 (fallback quando SSL falha)
Write-Host ""
Write-Host "5. Testando endpoint HTTP direto (porta 3001)..." -ForegroundColor Yellow
try {
    $body = @{mensagem_id="test"; thread_type="TASK"; thread_id="test"} | ConvertTo-Json
    $response = Invoke-WebRequest -Uri "http://212.85.0.249:3001/send-message" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "   [OK] Endpoint HTTP direto funciona! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Nota: Este é o fallback usado quando DNS/SSL falha" -ForegroundColor Gray
} catch {
    Write-Host "   [ERRO] Endpoint HTTP direto NAO funciona: $_" -ForegroundColor Red
    if ($_.Exception.Message -match "timeout|timed out") {
        Write-Host "   Timeout - servidor pode estar lento ou porta 3001 bloqueada no firewall" -ForegroundColor Yellow
        Write-Host "   Verifique firewall: ssh $SERVER 'ufw status | grep 3001'" -ForegroundColor Gray
    } elseif ($_.Exception.Message -match "refused|connection") {
        Write-Host "   Conexão recusada - Node.js pode não estar escutando na porta 3001" -ForegroundColor Yellow
    }
}

# Teste 6: Endpoint HTTPS funciona?
Write-Host ""
Write-Host "6. Testando endpoint HTTPS (via dominio)..." -ForegroundColor Yellow
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $body = @{mensagem_id="test"; thread_type="TASK"; thread_id="test"} | ConvertTo-Json
    $response = Invoke-WebRequest -Uri "https://$DOMAIN/send-message" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "   [OK] Endpoint HTTPS funciona! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "   [ERRO] Endpoint HTTPS NAO funciona: $_" -ForegroundColor Red
    if ($_.Exception.Message -match "name.*not.*resolved|ERR_NAME_NOT_RESOLVED") {
        Write-Host "   Erro de DNS - dominio nao resolve" -ForegroundColor Yellow
        Write-Host "   Solução: Configure DNS para apontar $DOMAIN para 212.85.0.249" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "certificate|SSL|TLS|ERR_CERT") {
        Write-Host "   Erro de certificado SSL - certificado inválido ou expirado" -ForegroundColor Yellow
        Write-Host "   Solução: Renove o certificado Let's Encrypt: ssh $SERVER 'certbot renew'" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "timeout|timed out") {
        Write-Host "   Timeout - servidor pode estar lento ou offline" -ForegroundColor Yellow
    } elseif ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "   Status: $statusCode" -ForegroundColor Yellow
        if ($statusCode -eq 401) {
            Write-Host "   Erro 401: Nginx pode estar bloqueando ou redirecionando" -ForegroundColor Yellow
            Write-Host "   Execute para corrigir: .\verificar_e_corrigir_nginx_send_message.ps1" -ForegroundColor Yellow
            Write-Host "   Ou verifique manualmente: ssh $SERVER 'grep -A 10 location.*send-message /etc/nginx/sites-enabled/*'" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Para diagnóstico completo, execute:" -ForegroundColor Yellow
Write-Host "  .\verificar_servidor_node_completo.ps1" -ForegroundColor White
Write-Host ""
