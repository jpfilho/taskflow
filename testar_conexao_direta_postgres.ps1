# Script para testar conexao direta ao Postgres (sem pooler)
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$PASSWORD = "KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testar Conexao Direta Postgres" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se supabase-db tem porta mapeada
Write-Host "[1/3] Verificando se supabase-db tem porta mapeada..." -ForegroundColor Yellow
$dbPort = ssh ${SERVER_USER}@${SERVER_IP} "docker port supabase-db 5432 2>&1"
if ($dbPort -match "5432") {
    Write-Host "Porta mapeada: $dbPort" -ForegroundColor Green
    Write-Host ""
    Write-Host "CONFIGURACAO ALTERNATIVA NO N8N:" -ForegroundColor Yellow
    Write-Host "  Use a porta mapeada do supabase-db diretamente" -ForegroundColor White
    Write-Host "  (nao use o pooler)" -ForegroundColor White
} else {
    Write-Host "Porta NAO esta mapeada no supabase-db" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "O pooler pode nao aceitar conexoes externas." -ForegroundColor Yellow
    Write-Host "Sugestao: Mapear porta do supabase-db diretamente" -ForegroundColor White
    Write-Host ""
    Write-Host "Execute:" -ForegroundColor Yellow
    Write-Host "  ssh $SERVER_USER@$SERVER_IP" -ForegroundColor Gray
    Write-Host "  cd /root/supabase/docker" -ForegroundColor Gray
    Write-Host "  # Edite docker-compose.yml e adicione na secao 'db':" -ForegroundColor Gray
    Write-Host "  #   ports:" -ForegroundColor Gray
    Write-Host "  #     - \"5433:5432\"  # Use porta diferente para evitar conflito" -ForegroundColor Gray
    Write-Host "  docker-compose up -d db" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[2/3] Verificando configuracao do pooler..." -ForegroundColor Yellow
$poolerEnv = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-pooler env | grep -i 'listen\|bind\|host'"
Write-Host $poolerEnv -ForegroundColor Gray

Write-Host ""
Write-Host "[3/3] Verificando se pooler aceita conexoes externas..." -ForegroundColor Yellow
Write-Host "Testando conexao externa ao pooler..." -ForegroundColor Gray
$testExternal = Test-NetConnection -ComputerName $SERVER_IP -Port 5432 -WarningAction SilentlyContinue
if ($testExternal.TcpTestSucceeded) {
    Write-Host "Porta esta aberta, mas pode nao aceitar conexoes do N8N" -ForegroundColor Yellow
    Write-Host "O pooler pode estar configurado apenas para conexoes internas" -ForegroundColor Yellow
} else {
    Write-Host "Porta nao esta acessivel externamente" -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "SOLUCAO RECOMENDADA:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se o pooler nao funcionar, mapee a porta do supabase-db diretamente:" -ForegroundColor White
Write-Host "  1. Edite /root/supabase/docker/docker-compose.yml" -ForegroundColor Gray
Write-Host "  2. Adicione na secao 'db' (supabase-db):" -ForegroundColor Gray
Write-Host "     ports:" -ForegroundColor Gray
Write-Host "       - \"5433:5432\"  # Porta 5433 no host, 5432 no container" -ForegroundColor Gray
Write-Host "  3. Reinicie: docker-compose up -d db" -ForegroundColor Gray
Write-Host "  4. Configure no N8N com Port: 5433" -ForegroundColor Gray
Write-Host ""
