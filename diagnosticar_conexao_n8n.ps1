# Script para diagnosticar conexao N8N com Postgres
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Diagnostico Conexao N8N -> Postgres" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se o container db esta rodando
Write-Host "[1/6] Verificando container supabase-db..." -ForegroundColor Yellow
$dbStatus = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=supabase-db' --format '{{.Status}}' 2>&1"
if ($dbStatus -match "Up") {
    Write-Host "Container esta rodando: $dbStatus" -ForegroundColor Green
} else {
    Write-Host "ERRO: Container nao esta rodando!" -ForegroundColor Red
    exit 1
}

# 2. Verificar mapeamento de porta
Write-Host ""
Write-Host "[2/6] Verificando mapeamento de porta..." -ForegroundColor Yellow
$portMapping = ssh ${SERVER_USER}@${SERVER_IP} "docker port supabase-db 5432 2>&1"
Write-Host "Mapeamento: $portMapping" -ForegroundColor Gray
if ($portMapping -match "5433") {
    Write-Host "Porta 5433 mapeada corretamente!" -ForegroundColor Green
} else {
    Write-Host "ERRO: Porta 5433 nao esta mapeada!" -ForegroundColor Red
    exit 1
}

# 3. Verificar se a porta 5433 esta escutando no servidor
Write-Host ""
Write-Host "[3/6] Verificando se porta 5433 esta escutando..." -ForegroundColor Yellow
$listening = ssh ${SERVER_USER}@${SERVER_IP} "netstat -tlnp 2>/dev/null | grep ':5433 ' || ss -tlnp 2>/dev/null | grep ':5433 ' 2>&1"
if ($listening) {
    Write-Host "Porta 5433 esta escutando:" -ForegroundColor Green
    Write-Host $listening -ForegroundColor Gray
} else {
    Write-Host "AVISO: Nao foi possivel verificar se porta esta escutando (pode ser normal)" -ForegroundColor Yellow
}

# 4. Verificar firewall
Write-Host ""
Write-Host "[4/6] Verificando firewall..." -ForegroundColor Yellow
$firewallStatus = ssh ${SERVER_USER}@${SERVER_IP} "ufw status 2>/dev/null | head -5 || firewall-cmd --list-all 2>/dev/null | head -10 || echo 'Firewall nao configurado ou comando nao disponivel' 2>&1"
Write-Host $firewallStatus -ForegroundColor Gray

# 5. Testar conexao local no servidor
Write-Host ""
Write-Host "[5/6] Testando conexao local no servidor..." -ForegroundColor Yellow
$localTest = ssh ${SERVER_USER}@${SERVER_IP} "timeout 5 bash -c 'echo > /dev/tcp/localhost/5433' 2>&1 && echo 'SUCESSO: Porta 5433 acessivel localmente' || echo 'ERRO: Porta 5433 nao acessivel localmente' 2>&1"
Write-Host $localTest -ForegroundColor Gray

# 6. Testar conexao Postgres diretamente
Write-Host ""
Write-Host "[6/6] Testando conexao Postgres na porta 5433..." -ForegroundColor Yellow
$pgTest = ssh ${SERVER_USER}@${SERVER_IP} "PGPASSWORD='KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA' timeout 5 psql -h localhost -p 5433 -U postgres -d postgres -c 'SELECT version();' 2>&1 | head -3"
if ($pgTest -match "PostgreSQL" -or $pgTest -match "version") {
    Write-Host "SUCESSO: Conexao Postgres funcionando!" -ForegroundColor Green
    Write-Host $pgTest -ForegroundColor Gray
} else {
    Write-Host "ERRO: Nao foi possivel conectar ao Postgres" -ForegroundColor Red
    Write-Host "Output: $pgTest" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Resumo:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se todos os testes passaram, mas o N8N ainda nao conecta:" -ForegroundColor Yellow
Write-Host "1. Verifique se o firewall permite conexoes externas na porta 5433" -ForegroundColor White
Write-Host "2. Verifique se o N8N esta na mesma rede ou tem acesso ao servidor" -ForegroundColor White
Write-Host "3. Tente usar 'Retry' no N8N apos alguns segundos" -ForegroundColor White
Write-Host "4. Verifique os logs do N8N para mais detalhes" -ForegroundColor White
Write-Host ""
