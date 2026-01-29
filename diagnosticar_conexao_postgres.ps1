# Script para diagnosticar problema de conexao Postgres N8N
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Diagnostico Conexao Postgres" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se porta esta acessivel
Write-Host "[1/6] Verificando porta 5432..." -ForegroundColor Yellow
$portCheck = Test-NetConnection -ComputerName $SERVER_IP -Port 5432 -WarningAction SilentlyContinue
if ($portCheck.TcpTestSucceeded) {
    Write-Host "Porta 5432 esta acessivel" -ForegroundColor Green
} else {
    Write-Host "Porta 5432 NAO esta acessivel!" -ForegroundColor Red
    exit 1
}

# 2. Verificar container pooler
Write-Host ""
Write-Host "[2/6] Verificando container supabase-pooler..." -ForegroundColor Yellow
$poolerStatus = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=supabase-pooler' --format '{{.Status}}'"
if ($poolerStatus) {
    Write-Host "Container pooler: $poolerStatus" -ForegroundColor Green
} else {
    Write-Host "Container pooler NAO esta rodando!" -ForegroundColor Red
    exit 1
}

# 3. Verificar logs do pooler para erros
Write-Host ""
Write-Host "[3/6] Verificando logs do pooler (ultimas 20 linhas)..." -ForegroundColor Yellow
$poolerLogs = ssh ${SERVER_USER}@${SERVER_IP} "docker logs supabase-pooler --tail 20 2>&1"
Write-Host $poolerLogs -ForegroundColor Gray

# 4. Verificar usuarios do Postgres
Write-Host ""
Write-Host "[4/6] Verificando usuarios do Postgres..." -ForegroundColor Yellow
Write-Host "Testando conexao com usuario 'postgres'..." -ForegroundColor Gray
$testPostgres = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT current_user;' 2>&1"
if ($testPostgres -match "current_user") {
    Write-Host "Usuario 'postgres' existe e funciona" -ForegroundColor Green
} else {
    Write-Host "Problema com usuario 'postgres': $testPostgres" -ForegroundColor Yellow
}

Write-Host "Testando conexao com usuario 'supabase_admin'..." -ForegroundColor Gray
$testAdmin = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U supabase_admin -d postgres -c 'SELECT current_user;' 2>&1"
if ($testAdmin -match "current_user") {
    Write-Host "Usuario 'supabase_admin' existe e funciona" -ForegroundColor Green
} else {
    Write-Host "Problema com usuario 'supabase_admin': $testAdmin" -ForegroundColor Yellow
}

# 5. Verificar se pooler aceita conexoes externas
Write-Host ""
Write-Host "[5/6] Verificando configuracao do pooler..." -ForegroundColor Yellow
$poolerConfig = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-pooler env | grep -E '(POSTGRES|DATABASE|POOLER)' | head -10"
Write-Host $poolerConfig -ForegroundColor Gray

# 6. Testar conexao via pooler
Write-Host ""
Write-Host "[6/6] Testando conexao via pooler..." -ForegroundColor Yellow
Write-Host "Tentando conectar do servidor via pooler..." -ForegroundColor Gray
$testConnection = ssh ${SERVER_USER}@${SERVER_IP} "PGPASSWORD=KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA psql -h localhost -p 5432 -U postgres -d postgres -c 'SELECT version();' 2>&1 | head -5"
if ($testConnection -match "PostgreSQL") {
    Write-Host "Conexao via pooler funcionou!" -ForegroundColor Green
    Write-Host $testConnection -ForegroundColor Gray
} else {
    Write-Host "Conexao via pooler falhou:" -ForegroundColor Red
    Write-Host $testConnection -ForegroundColor Gray
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "SUGESTOES:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Tente usar usuario 'supabase_admin' em vez de 'postgres'" -ForegroundColor White
Write-Host "2. Verifique se precisa habilitar SSL no N8N" -ForegroundColor White
Write-Host "3. Verifique se o pooler aceita conexoes externas" -ForegroundColor White
Write-Host "4. Tente conectar diretamente ao supabase-db (porta precisa estar mapeada)" -ForegroundColor White
Write-Host ""
