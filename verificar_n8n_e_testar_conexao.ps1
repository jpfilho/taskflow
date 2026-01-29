# Script para verificar onde o N8N esta rodando e testar conexao
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verificar N8N e Testar Conexao" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se N8N esta rodando no mesmo servidor
Write-Host "[1/4] Verificando se N8N esta no mesmo servidor..." -ForegroundColor Yellow
$n8nRunning = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=n8n' --format '{{.Names}}' 2>&1"
if ($n8nRunning -match "n8n") {
    Write-Host "N8N encontrado no servidor: $n8nRunning" -ForegroundColor Green
    Write-Host ""
    Write-Host "IMPORTANTE: Se o N8N esta no mesmo servidor, use 'localhost' ou '127.0.0.1' em vez de '$SERVER_IP'!" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "N8N nao encontrado no servidor (pode estar em outro lugar)" -ForegroundColor Gray
    Write-Host "Use o IP externo: $SERVER_IP" -ForegroundColor White
}

# Testar conexao local (se N8N estiver no mesmo servidor)
Write-Host ""
Write-Host "[2/4] Testando conexao local (localhost:5433)..." -ForegroundColor Yellow
$localTest = ssh ${SERVER_USER}@${SERVER_IP} "timeout 3 bash -c 'echo > /dev/tcp/localhost/5433' 2>&1 && echo 'SUCESSO' || echo 'FALHOU' 2>&1"
if ($localTest -match "SUCESSO") {
    Write-Host "Conexao local funcionando!" -ForegroundColor Green
} else {
    Write-Host "Conexao local falhou: $localTest" -ForegroundColor Red
}

# Testar conexao externa
Write-Host ""
Write-Host "[3/4] Testando conexao externa ($SERVER_IP:5433)..." -ForegroundColor Yellow
try {
    $externalTest = Test-NetConnection -ComputerName $SERVER_IP -Port 5433 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($externalTest) {
        Write-Host "Conexao externa funcionando!" -ForegroundColor Green
    } else {
        Write-Host "Conexao externa falhou!" -ForegroundColor Red
    }
} catch {
    Write-Host "Erro ao testar conexao externa: $_" -ForegroundColor Red
}

# Verificar listen_addresses do Postgres
Write-Host ""
Write-Host "[4/4] Verificando configuracao do Postgres..." -ForegroundColor Yellow
$listenAddr = ssh ${SERVER_USER}@${SERVER_IP} 'docker exec supabase-db psql -U postgres -t -c "SHOW listen_addresses;" 2>&1' | Out-String
$listenAddr = $listenAddr.Trim()
Write-Host "listen_addresses: $listenAddr" -ForegroundColor Gray

if ($listenAddr -match "\*" -or $listenAddr -match "0\.0\.0\.0" -or $listenAddr -match "all") {
    Write-Host "OK: Postgres aceita conexoes de qualquer endereco" -ForegroundColor Green
} else {
    Write-Host "AVISO: Postgres pode estar restrito a conexoes locais" -ForegroundColor Yellow
    Write-Host "Se o N8N esta em outro servidor, pode ser necessario configurar listen_addresses = '*'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Recomendacoes:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($n8nRunning -match "n8n") {
    Write-Host "1. No N8N, use estas configuracoes:" -ForegroundColor White
    Write-Host "   Host: localhost (ou 127.0.0.1)" -ForegroundColor Green
    Write-Host "   Port: 5433" -ForegroundColor Green
    Write-Host "   Database: postgres" -ForegroundColor Green
    Write-Host "   User: postgres" -ForegroundColor Green
    Write-Host "   Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor Green
    Write-Host "   SSL: Desabilitado" -ForegroundColor Green
} else {
    Write-Host "1. No N8N, use estas configuracoes:" -ForegroundColor White
    Write-Host "   Host: $SERVER_IP" -ForegroundColor Green
    Write-Host "   Port: 5433" -ForegroundColor Green
    Write-Host "   Database: postgres" -ForegroundColor Green
    Write-Host "   User: postgres" -ForegroundColor Green
    Write-Host "   Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor Green
    Write-Host "   SSL: Desabilitado" -ForegroundColor Green
}

Write-Host ""
Write-Host "2. Se ainda nao funcionar, verifique:" -ForegroundColor White
Write-Host "   - Logs do N8N para ver o erro exato" -ForegroundColor Gray
Write-Host "   - Se ha firewall do provedor/hosting bloqueando" -ForegroundColor Gray
Write-Host "   - Se o N8N tem acesso de rede ao servidor" -ForegroundColor Gray
Write-Host ""
