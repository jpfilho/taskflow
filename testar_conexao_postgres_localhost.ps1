# Script para testar conexao Postgres via localhost:5433
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testar Conexao Postgres (localhost:5433)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Testar conexao usando o psql dentro do container
Write-Host "[1/2] Testando conexao via container supabase-db..." -ForegroundColor Yellow
$test1 = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -h localhost -p 5432 -U postgres -d postgres -c 'SELECT version();' 2>&1"
Write-Host "Resultado (conexao interna do container):" -ForegroundColor Gray
Write-Host $test1 -ForegroundColor Gray

# Testar conexao do host para o container na porta 5433
Write-Host ""
Write-Host "[2/2] Testando conexao do host para localhost:5433..." -ForegroundColor Yellow

# Verificar se psql esta instalado no host
$psqlExists = ssh ${SERVER_USER}@${SERVER_IP} "which psql >/dev/null 2>&1 && echo 'yes' || echo 'no' 2>&1"
if ($psqlExists -match "yes") {
    Write-Host "psql encontrado no host, testando conexao..." -ForegroundColor Green
    $test2 = ssh ${SERVER_USER}@${SERVER_IP} "PGPASSWORD='KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA' psql -h localhost -p 5433 -U postgres -d postgres -c 'SELECT version();' 2>&1"
    Write-Host "Resultado (conexao do host):" -ForegroundColor Gray
    Write-Host $test2 -ForegroundColor Gray
    
    if ($test2 -match "PostgreSQL" -or $test2 -match "version") {
        Write-Host ""
        Write-Host "SUCESSO: Conexao funcionando via localhost:5433!" -ForegroundColor Green
        Write-Host ""
        Write-Host "No N8N, use:" -ForegroundColor Yellow
        Write-Host "  Host: localhost" -ForegroundColor White
        Write-Host "  Port: 5433" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "ERRO: Nao foi possivel conectar via localhost:5433" -ForegroundColor Red
        Write-Host "Verifique se o container esta rodando e a porta esta mapeada" -ForegroundColor Yellow
    }
} else {
    Write-Host "psql nao encontrado no host (normal - Postgres esta no Docker)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Testando via netcat/telnet..." -ForegroundColor Yellow
    $ncTest = ssh ${SERVER_USER}@${SERVER_IP} "timeout 3 bash -c 'echo > /dev/tcp/localhost/5433' 2>&1 && echo 'Porta 5433 acessivel' || echo 'Porta 5433 NAO acessivel' 2>&1"
    Write-Host $ncTest -ForegroundColor Gray
    
    if ($ncTest -match "acessivel") {
        Write-Host ""
        Write-Host "Porta 5433 esta acessivel localmente!" -ForegroundColor Green
        Write-Host ""
        Write-Host "No N8N, use:" -ForegroundColor Yellow
        Write-Host "  Host: localhost" -ForegroundColor White
        Write-Host "  Port: 5433" -ForegroundColor White
        Write-Host "  Database: postgres" -ForegroundColor White
        Write-Host "  User: postgres" -ForegroundColor White
        Write-Host "  Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor White
        Write-Host "  Ignore SSL Issues: Ativado" -ForegroundColor White
        Write-Host "  SSL: Disable" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "ERRO: Porta 5433 nao esta acessivel localmente" -ForegroundColor Red
        Write-Host "Verifique o mapeamento de porta do container" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Resumo" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se a porta esta acessivel, configure no N8N:" -ForegroundColor White
Write-Host "  Host: localhost (ou 127.0.0.1)" -ForegroundColor Green
Write-Host "  Port: 5433" -ForegroundColor Green
Write-Host "  Database: postgres" -ForegroundColor Green
Write-Host "  User: postgres" -ForegroundColor Green
Write-Host "  Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor Green
Write-Host "  Ignore SSL Issues: ✅ Ativado" -ForegroundColor Green
Write-Host "  SSL: Disable" -ForegroundColor Green
Write-Host ""
