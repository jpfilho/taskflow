# Script para corrigir porta do Postgres Supabase Docker
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Corrigir Porta Postgres Supabase" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Encontrar docker-compose.yml do Supabase
Write-Host "[1/5] Procurando docker-compose.yml do Supabase..." -ForegroundColor Yellow
$composePath = ssh ${SERVER_USER}@${SERVER_IP} "find /opt /home /root -name 'docker-compose.yml' -o -name 'docker-compose.yaml' 2>/dev/null | xargs grep -l 'supabase-db' 2>/dev/null | head -1"
if (-not $composePath) {
    # Tentar encontrar em diretórios comuns do Supabase
    $composePath = ssh ${SERVER_USER}@${SERVER_IP} "find /opt/supabase /root/supabase /home/*/supabase -name 'docker-compose.yml' 2>/dev/null | head -1"
}

if ($composePath) {
    Write-Host "Arquivo encontrado: $composePath" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "[2/5] Verificando configuração atual de portas..." -ForegroundColor Yellow
    $currentPorts = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 10 'supabase-db:' $composePath | grep -E 'ports:|5432' | head -5"
    Write-Host $currentPorts -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "[3/5] Verificando se porta já está mapeada..." -ForegroundColor Yellow
    $hasPortMapping = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 10 'supabase-db:' $composePath | grep -E '5432:5432|0.0.0.0:5432'"
    if ($hasPortMapping) {
        Write-Host "Porta já está mapeada!" -ForegroundColor Green
        Write-Host $hasPortMapping -ForegroundColor Gray
        Write-Host ""
        Write-Host "Reiniciando container para aplicar configuração..." -ForegroundColor Yellow
        $composeDir = ssh ${SERVER_USER}@${SERVER_IP} "dirname $composePath"
        ssh ${SERVER_USER}@${SERVER_IP} "cd $composeDir && docker-compose restart supabase-db"
        Write-Host "Container reiniciado!" -ForegroundColor Green
    } else {
        Write-Host "Porta NÃO está mapeada. Precisa adicionar mapeamento." -ForegroundColor Red
        Write-Host ""
        Write-Host "SOLUÇÃO MANUAL:" -ForegroundColor Yellow
        Write-Host "1. Acesse o servidor: ssh root@212.85.0.249" -ForegroundColor White
        Write-Host "2. Edite o arquivo: $composePath" -ForegroundColor White
        Write-Host "3. Na seção 'supabase-db:', adicione:" -ForegroundColor White
        Write-Host "   ports:" -ForegroundColor Gray
        Write-Host "     - `"5432:5432`"" -ForegroundColor Gray
        Write-Host "4. Salve e execute: docker-compose up -d" -ForegroundColor White
    }
} else {
    Write-Host "docker-compose.yml não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verificando se o container foi criado manualmente..." -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "[2/5] Obtendo comando de criação do container..." -ForegroundColor Yellow
    $containerCmd = ssh ${SERVER_USER}@${SERVER_IP} "docker inspect supabase-db --format '{{.Config.Image}}' 2>&1"
    Write-Host "Imagem: $containerCmd" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "SOLUÇÃO: Recriar container com mapeamento de porta" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Opção 1: Usar docker run com -p 5432:5432" -ForegroundColor White
    Write-Host "Opção 2: Criar docker-compose.yml" -ForegroundColor White
    Write-Host "Opção 3: Usar conexão interna (se N8N estiver no mesmo servidor)" -ForegroundColor White
}

# 4. Verificar credenciais
Write-Host ""
Write-Host "[4/5] Verificando credenciais do Postgres..." -ForegroundColor Yellow
$envFile = ssh ${SERVER_USER}@${SERVER_IP} "find $(dirname $composePath) -name '.env' 2>/dev/null | head -1"
if ($envFile) {
    Write-Host "Arquivo .env encontrado: $envFile" -ForegroundColor Green
    $dbUser = ssh ${SERVER_USER}@${SERVER_IP} "grep 'POSTGRES_USER' $envFile | cut -d'=' -f2"
    $dbPass = ssh ${SERVER_USER}@${SERVER_IP} "grep 'POSTGRES_PASSWORD' $envFile | cut -d'=' -f2"
    Write-Host "User: $dbUser" -ForegroundColor Gray
    Write-Host "Password: [oculto]" -ForegroundColor Gray
} else {
    Write-Host "Verificando variáveis de ambiente do container..." -ForegroundColor Yellow
    $dbUser = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db env | grep 'POSTGRES_USER' | cut -d'=' -f2"
    Write-Host "User: $dbUser" -ForegroundColor Gray
}

# 5. Testar conexão
Write-Host ""
Write-Host "[5/5] Testando conexão..." -ForegroundColor Yellow
$testResult = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT 1;' 2>&1 | head -1"
if ($testResult -match "1") {
    Write-Host "Conexão dentro do container OK!" -ForegroundColor Green
} else {
    Write-Host "Conexão falhou: $testResult" -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Configuração N8N" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se a porta for mapeada (5432:5432):" -ForegroundColor White
Write-Host "  Host: 212.85.0.249" -ForegroundColor Gray
Write-Host "  Port: 5432" -ForegroundColor Gray
Write-Host "  User: postgres (ou $dbUser)" -ForegroundColor Gray
Write-Host ""
Write-Host "Se N8N estiver no mesmo servidor:" -ForegroundColor White
Write-Host "  Host: 127.0.0.1 OU supabase-db" -ForegroundColor Gray
Write-Host "  Port: 5432" -ForegroundColor Gray
Write-Host "  User: postgres (ou $dbUser)" -ForegroundColor Gray
Write-Host ""
