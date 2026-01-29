# ============================================
# CORRIGIR ERRO SSL TELEGRAM
# ============================================
# Este script verifica e corrige problemas de SSL/DNS
# que impedem o Flutter de se comunicar com o servidor Node.js

$SERVER = "root@212.85.0.249"
$DOMAIN = "api.taskflowv3.com.br"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGINDO ERRO SSL TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se porta 3001 está acessível externamente
Write-Host "1. Verificando se porta 3001 está acessível..." -ForegroundColor Yellow
$portCheck = ssh $SERVER "netstat -tlnp 2>/dev/null | grep :3001 || ss -tlnp 2>/dev/null | grep :3001"
if ($portCheck -match "0\.0\.0\.0:3001|:::3001") {
    Write-Host "   [OK] Porta 3001 está escutando em todas as interfaces" -ForegroundColor Green
} elseif ($portCheck -match "127\.0\.0\.1:3001|localhost:3001") {
    Write-Host "   [AVISO] Porta 3001 está escutando apenas em localhost" -ForegroundColor Yellow
    Write-Host "   Isso impedirá conexões externas via IP direto" -ForegroundColor Yellow
    Write-Host "   Solução: Modifique o código Node.js para escutar em 0.0.0.0" -ForegroundColor Yellow
} else {
    Write-Host "   [ERRO] Porta 3001 não encontrada" -ForegroundColor Red
    Write-Host "   Verifique se o serviço telegram-webhook está rodando" -ForegroundColor Yellow
}

# 2. Verificar firewall
Write-Host ""
Write-Host "2. Verificando firewall..." -ForegroundColor Yellow
$firewallCheck = ssh $SERVER "ufw status 2>&1 | head -5"
if ($firewallCheck -match "Status: active") {
    Write-Host "   [AVISO] Firewall está ativo" -ForegroundColor Yellow
    $port3001Check = ssh $SERVER "ufw status | grep 3001"
    if ($port3001Check) {
        Write-Host "   [OK] Porta 3001 está liberada no firewall" -ForegroundColor Green
    } else {
        Write-Host "   [ERRO] Porta 3001 NÃO está liberada no firewall" -ForegroundColor Red
        Write-Host "   Liberando porta 3001..." -ForegroundColor Yellow
        ssh $SERVER "ufw allow 3001/tcp comment 'Telegram webhook HTTP fallback'"
        Write-Host "   [OK] Porta 3001 liberada" -ForegroundColor Green
    }
} else {
    Write-Host "   [OK] Firewall não está ativo ou não está bloqueando" -ForegroundColor Green
}

# 3. Verificar DNS
Write-Host ""
Write-Host "3. Verificando DNS..." -ForegroundColor Yellow
try {
    $dns = Resolve-DnsName -Name $DOMAIN -ErrorAction Stop
    $dnsIp = $dns[0].IPAddress
    if ($dnsIp -eq "212.85.0.249") {
        Write-Host "   [OK] DNS resolve corretamente: $dnsIp" -ForegroundColor Green
    } else {
        Write-Host "   [AVISO] DNS resolve para IP diferente: $dnsIp" -ForegroundColor Yellow
        Write-Host "   Esperado: 212.85.0.249" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERRO] DNS não resolve: $_" -ForegroundColor Red
    Write-Host "   Configure o DNS para apontar $DOMAIN para 212.85.0.249" -ForegroundColor Yellow
}

# 4. Testar HTTP direto na porta 3001
Write-Host ""
Write-Host "4. Testando HTTP direto na porta 3001..." -ForegroundColor Yellow
try {
    $body = @{mensagem_id="test"; thread_type="TASK"; thread_id="test"} | ConvertTo-Json
    $response = Invoke-WebRequest -Uri "http://212.85.0.249:3001/send-message" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "   [OK] HTTP direto funciona! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   O Flutter poderá usar este fallback quando DNS/SSL falhar" -ForegroundColor Gray
} catch {
    Write-Host "   [ERRO] HTTP direto não funciona: $_" -ForegroundColor Red
    if ($_.Exception.Message -match "timeout|timed out") {
        Write-Host "   Timeout - verifique se o Node.js está rodando" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "refused|connection") {
        Write-Host "   Conexão recusada - verifique firewall e se Node.js escuta em 0.0.0.0" -ForegroundColor Yellow
    }
}

# 5. Testar HTTPS via domínio
Write-Host ""
Write-Host "5. Testando HTTPS via domínio..." -ForegroundColor Yellow
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $body = @{mensagem_id="test"; thread_type="TASK"; thread_id="test"} | ConvertTo-Json
    $response = Invoke-WebRequest -Uri "https://$DOMAIN/send-message" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "   [OK] HTTPS via domínio funciona! Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   Esta é a forma preferencial de conexão" -ForegroundColor Gray
} catch {
    Write-Host "   [ERRO] HTTPS via domínio não funciona: $_" -ForegroundColor Red
    if ($_.Exception.Message -match "name.*not.*resolved|ERR_NAME_NOT_RESOLVED") {
        Write-Host "   Erro de DNS - configure o DNS primeiro" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "certificate|SSL|TLS|ERR_CERT") {
        Write-Host "   Erro de certificado SSL" -ForegroundColor Yellow
        Write-Host "   Verifique: ssh $SERVER 'certbot certificates'" -ForegroundColor Gray
    }
}

# Resumo
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RESUMO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "O Flutter agora usa HTTP direto na porta 3001 como fallback" -ForegroundColor White
Write-Host "quando DNS ou SSL falha. Isso resolve o erro ERR_CERT_AUTHORITY_INVALID." -ForegroundColor White
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "1. Se HTTP direto não funcionou, verifique firewall e Node.js" -ForegroundColor White
Write-Host "2. Configure DNS para que $DOMAIN sempre resolva para 212.85.0.249" -ForegroundColor White
Write-Host "3. Monitore os logs do Flutter para confirmar que está funcionando" -ForegroundColor White
Write-Host ""
