# Script para obter credenciais do Postgres Supabase
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$SUPABASE_DIR = "/root/supabase"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Obter Credenciais Postgres Supabase" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Procurar arquivo .env
Write-Host "Procurando arquivo .env..." -ForegroundColor Yellow
# Primeiro tentar locais comuns
$envFile = ssh ${SERVER_USER}@${SERVER_IP} "test -f $SUPABASE_DIR/.env && echo $SUPABASE_DIR/.env || (test -f $SUPABASE_DIR/docker/.env && echo $SUPABASE_DIR/docker/.env || find $SUPABASE_DIR -maxdepth 2 -name '.env' 2>/dev/null | grep -v functions | head -1)"

if (-not $envFile) {
    Write-Host "Arquivo .env nao encontrado" -ForegroundColor Yellow
    Write-Host "Procurando em docker-compose.yml..." -ForegroundColor Yellow
    
    # Tentar obter do docker-compose.yml
    $composePath = "$SUPABASE_DIR/docker/docker-compose.yml"
    $dbPassword = ssh ${SERVER_USER}@${SERVER_IP} "grep POSTGRES_PASSWORD $composePath | head -1"
    
    if ($dbPassword) {
        Write-Host ""
        Write-Host "Credenciais encontradas:" -ForegroundColor Green
        Write-Host "  Password: $dbPassword" -ForegroundColor Gray
    } else {
        Write-Host "Nao foi possivel obter credenciais automaticamente" -ForegroundColor Red
        Write-Host ""
        Write-Host "Verifique manualmente:" -ForegroundColor Yellow
        Write-Host "  ssh root@$SERVER_IP" -ForegroundColor White
        Write-Host "  cat $SUPABASE_DIR/.env | grep POSTGRES" -ForegroundColor White
    }
} else {
    Write-Host "Arquivo encontrado: $envFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Credenciais Postgres:" -ForegroundColor Yellow
    
    $credentials = ssh ${SERVER_USER}@${SERVER_IP} "grep ^POSTGRES_DB= $envFile; grep ^POSTGRES_USER= $envFile; grep ^POSTGRES_PASSWORD= $envFile; grep ^POSTGRES_PORT= $envFile; grep ^POSTGRES_HOST= $envFile"
    
    if ($credentials) {
        Write-Host $credentials -ForegroundColor Gray
    } else {
        Write-Host "Nenhuma credencial POSTGRES encontrada neste arquivo." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Tentando localizar arquivo .env principal..." -ForegroundColor Yellow
        $mainEnv = ssh ${SERVER_USER}@${SERVER_IP} "ls -la $SUPABASE_DIR/.env 2>/dev/null || ls -la $SUPABASE_DIR/docker/.env 2>/dev/null || echo 'nao_encontrado'"
        if ($mainEnv -ne "nao_encontrado") {
            Write-Host "Arquivo principal: $mainEnv" -ForegroundColor Gray
            Write-Host "Execute manualmente:" -ForegroundColor Yellow
            Write-Host "  ssh root@$SERVER_IP" -ForegroundColor White
            Write-Host "  cat $SUPABASE_DIR/.env | grep POSTGRES" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Configuracao N8N:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Host: $SERVER_IP" -ForegroundColor White
Write-Host "Port: 5432" -ForegroundColor White
Write-Host "Database: [use POSTGRES_DB do .env]" -ForegroundColor White
Write-Host "User: [use POSTGRES_USER do .env]" -ForegroundColor White
Write-Host "Password: [use POSTGRES_PASSWORD do .env]" -ForegroundColor White
Write-Host ""
