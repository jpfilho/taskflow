# Script para testar conexão Postgres do N8N
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Teste de Conexão Postgres para N8N" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se o Postgres está rodando
Write-Host "[1/6] Verificando se o Postgres está rodando..." -ForegroundColor Yellow
$pgStatus = ssh ${SERVER_USER}@${SERVER_IP} "systemctl status postgresql 2>&1 | head -5"
Write-Host $pgStatus -ForegroundColor Gray

# 2. Verificar se está escutando na porta 5432
Write-Host ""
Write-Host "[2/6] Verificando se está escutando na porta 5432..." -ForegroundColor Yellow
$portCheck = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"netstat -tuln | grep 5432 || ss -tuln | grep 5432`""
if ($portCheck) {
    Write-Host "Porta 5432 está sendo escutada:" -ForegroundColor Green
    Write-Host $portCheck -ForegroundColor Gray
} else {
    Write-Host "ATENÇÃO: Porta 5432 não está sendo escutada!" -ForegroundColor Red
}

# 3. Verificar configuração listen_addresses
Write-Host ""
Write-Host "[3/6] Verificando configuração listen_addresses..." -ForegroundColor Yellow
$listenCheck = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"grep -r 'listen_addresses' /etc/postgresql/*/main/postgresql.conf 2>/dev/null | head -1 || echo 'Arquivo não encontrado'`""
Write-Host $listenCheck -ForegroundColor Gray

# 4. Verificar pg_hba.conf (permissões de conexão)
Write-Host ""
Write-Host "[4/6] Verificando pg_hba.conf (permissões de conexão)..." -ForegroundColor Yellow
$pgHbaCheck = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"grep -E '^host|^local' /etc/postgresql/*/main/pg_hba.conf 2>/dev/null | tail -5 || echo 'Arquivo não encontrado'`""
Write-Host $pgHbaCheck -ForegroundColor Gray

# 5. Verificar usuários do Postgres
Write-Host ""
Write-Host "[5/6] Verificando usuários do Postgres..." -ForegroundColor Yellow
$usersCheck = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"sudo -u postgres psql -c '\du' 2>&1 | head -20`""
Write-Host $usersCheck -ForegroundColor Gray

# 6. Testar conexão local (do servidor)
Write-Host ""
Write-Host "[6/6] Testando conexão local (do servidor)..." -ForegroundColor Yellow
$localTest = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"sudo -u postgres psql -h localhost -U postgres -d postgres -c 'SELECT version();' 2>&1 | head -3`""
if ($localTest -match "PostgreSQL") {
    Write-Host "Conexão local funcionando!" -ForegroundColor Green
    Write-Host $localTest -ForegroundColor Gray
} else {
    Write-Host "Conexão local falhou:" -ForegroundColor Red
    Write-Host $localTest -ForegroundColor Red
}

# Verificar se está em Docker
Write-Host ""
Write-Host "Verificando se o Postgres está em Docker..." -ForegroundColor Yellow
$dockerCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker ps | grep -i postgres"
if ($dockerCheck) {
    Write-Host "Postgres encontrado em Docker:" -ForegroundColor Yellow
    Write-Host $dockerCheck -ForegroundColor Gray
    Write-Host ""
    Write-Host "IMPORTANTE: Se o Postgres estiver em Docker, verifique:" -ForegroundColor Yellow
    Write-Host "  1. Se a porta está mapeada corretamente (ex: 5432:5432)" -ForegroundColor White
    Write-Host "  2. Se o container está acessível externamente" -ForegroundColor White
    Write-Host "  3. Se o usuário e senha estão corretos" -ForegroundColor White
} else {
    Write-Host "Postgres não está em Docker (instalação nativa)" -ForegroundColor Green
}

# Verificar firewall
Write-Host ""
Write-Host "Verificando firewall..." -ForegroundColor Yellow
$firewallCheck = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"ufw status | grep 5432 || firewall-cmd --list-ports | grep 5432 || echo 'Porta 5432 não encontrada nas regras do firewall'`""
Write-Host $firewallCheck -ForegroundColor Gray

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Diagnóstico Concluído!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuração recomendada no N8N:" -ForegroundColor Yellow
Write-Host "  Host: 212.85.0.249" -ForegroundColor White
Write-Host "  Port: 5432" -ForegroundColor White
Write-Host "  Database: postgres" -ForegroundColor White
Write-Host "  User: postgres (ou conforme mostrado acima)" -ForegroundColor White
Write-Host "  Password: [senha do Supabase]" -ForegroundColor White
Write-Host "  SSL: Prefer (ou desabilitado se não usar SSL)" -ForegroundColor White
Write-Host ""
