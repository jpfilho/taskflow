# Script para testar conexao Postgres via supabase-pooler
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testar Conexao Postgres" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se porta esta acessivel
Write-Host "[1/3] Verificando porta 5432..." -ForegroundColor Yellow
$portCheck = Test-NetConnection -ComputerName $SERVER_IP -Port 5432 -WarningAction SilentlyContinue
if ($portCheck.TcpTestSucceeded) {
    Write-Host "Porta 5432 esta acessivel!" -ForegroundColor Green
} else {
    Write-Host "Porta 5432 NAO esta acessivel" -ForegroundColor Red
    Write-Host "Verifique firewall ou configuracao do container" -ForegroundColor Yellow
    exit 1
}

# 2. Verificar container pooler
Write-Host ""
Write-Host "[2/3] Verificando container supabase-pooler..." -ForegroundColor Yellow
$poolerStatus = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=supabase-pooler' --format '{{.Status}}'"
if ($poolerStatus) {
    Write-Host "Container pooler: $poolerStatus" -ForegroundColor Green
} else {
    Write-Host "Container pooler nao esta rodando!" -ForegroundColor Red
    exit 1
}

# 3. Verificar mapeamento de porta
Write-Host ""
Write-Host "[3/3] Verificando mapeamento de porta..." -ForegroundColor Yellow
$portMapping = ssh ${SERVER_USER}@${SERVER_IP} "docker port supabase-pooler 5432 2>&1"
if ($portMapping -match "5432") {
    Write-Host "Porta mapeada: $portMapping" -ForegroundColor Green
} else {
    Write-Host "Porta nao esta mapeada!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Configuracao para N8N:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Host: $SERVER_IP" -ForegroundColor White
Write-Host "Port: 5432" -ForegroundColor White
Write-Host "Database: postgres" -ForegroundColor White
Write-Host "User: postgres" -ForegroundColor White
Write-Host "Password: [senha do Supabase]" -ForegroundColor White
Write-Host ""
Write-Host "NOTA: Se usar 'postgres' nao funcionar, tente:" -ForegroundColor Yellow
Write-Host "  User: supabase_admin" -ForegroundColor Gray
Write-Host "  Database: postgres" -ForegroundColor Gray
Write-Host ""
