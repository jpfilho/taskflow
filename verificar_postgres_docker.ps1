# Script para verificar e corrigir Postgres Docker do Supabase
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verificação Postgres Docker (Supabase)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar container e mapeamento de portas
Write-Host "[1/5] Verificando container Postgres Docker..." -ForegroundColor Yellow
$containerInfo = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=supabase-db' --format '{{.Names}}\t{{.Ports}}\t{{.Image}}'"
Write-Host $containerInfo -ForegroundColor Gray

# 2. Verificar se a porta está mapeada
Write-Host ""
Write-Host "[2/5] Verificando mapeamento de portas..." -ForegroundColor Yellow
$portMapping = ssh ${SERVER_USER}@${SERVER_IP} "docker port supabase-db 2>&1"
Write-Host $portMapping -ForegroundColor Gray

# 3. Verificar docker-compose ou configuração
Write-Host ""
Write-Host "[3/5] Procurando docker-compose.yml do Supabase..." -ForegroundColor Yellow
$composeFile = ssh ${SERVER_USER}@${SERVER_IP} "find /opt /home /root -name 'docker-compose.yml' -path '*/supabase/*' 2>/dev/null | head -1"
if ($composeFile) {
    Write-Host "Arquivo encontrado: $composeFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Verificando configuração de portas..." -ForegroundColor Yellow
    $portConfig = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 5 'supabase-db:' $composeFile | grep -E 'ports:|5432' | head -5"
    Write-Host $portConfig -ForegroundColor Gray
} else {
    Write-Host "docker-compose.yml não encontrado. Verificando variáveis de ambiente do container..." -ForegroundColor Yellow
    $envVars = ssh ${SERVER_USER}@${SERVER_IP} "docker inspect supabase-db --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E 'POSTGRES|DB' | head -10"
    Write-Host $envVars -ForegroundColor Gray
}

# 4. Verificar credenciais do Supabase
Write-Host ""
Write-Host "[4/5] Verificando credenciais do Supabase..." -ForegroundColor Yellow
$supabaseEnv = ssh ${SERVER_USER}@${SERVER_IP} "find /opt /home /root -name '.env' -path '*/supabase/*' 2>/dev/null | head -1"
if ($supabaseEnv) {
    Write-Host "Arquivo .env encontrado: $supabaseEnv" -ForegroundColor Green
    Write-Host ""
    Write-Host "Credenciais do Postgres:" -ForegroundColor Yellow
    $dbCreds = ssh ${SERVER_USER}@${SERVER_IP} "grep -E 'POSTGRES_PASSWORD|POSTGRES_USER|POSTGRES_DB' $supabaseEnv | head -5"
    Write-Host $dbCreds -ForegroundColor Gray
} else {
    Write-Host ".env não encontrado. Tentando obter do container..." -ForegroundColor Yellow
    $containerCreds = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db env | grep -E 'POSTGRES|DB' | head -5"
    Write-Host $containerCreds -ForegroundColor Gray
}

# 5. Testar conexão dentro do container
Write-Host ""
Write-Host "[5/5] Testando conexão dentro do container..." -ForegroundColor Yellow
$testConn = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT version();' 2>&1 | head -3"
if ($testConn -match "PostgreSQL") {
    Write-Host "Conexão dentro do container funcionando!" -ForegroundColor Green
    Write-Host $testConn -ForegroundColor Gray
} else {
    Write-Host "Conexão dentro do container falhou:" -ForegroundColor Red
    Write-Host $testConn -ForegroundColor Red
}

# Verificar se precisa mapear porta
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Análise" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$portCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker port supabase-db 2>&1"
if ($portCheck -match "5432") {
    Write-Host "✅ Porta 5432 está mapeada!" -ForegroundColor Green
    Write-Host $portCheck -ForegroundColor Gray
} else {
    Write-Host "❌ Porta 5432 NÃO está mapeada para o host!" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUÇÃO: É necessário mapear a porta do container para o host." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Opção 1: Parar e recriar o container com mapeamento de porta" -ForegroundColor White
    Write-Host "Opção 2: Usar docker-compose e adicionar mapeamento de porta" -ForegroundColor White
    Write-Host "Opção 3: Usar host do container diretamente (se N8N estiver no mesmo servidor)" -ForegroundColor White
}

Write-Host ""
Write-Host "Configuração recomendada no N8N:" -ForegroundColor Yellow
Write-Host "  Se a porta estiver mapeada:" -ForegroundColor White
Write-Host "    Host: 212.85.0.249" -ForegroundColor Gray
Write-Host "    Port: 5432" -ForegroundColor Gray
Write-Host ""
Write-Host "  Se N8N estiver no mesmo servidor (212.85.0.249):" -ForegroundColor White
Write-Host "    Host: supabase-db (nome do container) OU 127.0.0.1" -ForegroundColor Gray
Write-Host "    Port: 5432" -ForegroundColor Gray
Write-Host ""
