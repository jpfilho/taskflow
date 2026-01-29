# Script para executar migracao SQL de DELETE bidirecional no servidor

$SERVER = "root@212.85.0.249"
$MIGRATION_FILE = "supabase/migrations/20260126_bidirectional_delete.sql"
$PROJECT_DIR = "/root/telegram-webhook"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Executando migracao DELETE bidirecional" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Servidor: $SERVER" -ForegroundColor Yellow
Write-Host "Arquivo: $MIGRATION_FILE" -ForegroundColor Yellow
Write-Host ""

# Verificar se o arquivo existe localmente
if (-not (Test-Path $MIGRATION_FILE)) {
    Write-Host "Erro: Arquivo de migracao nao encontrado: $MIGRATION_FILE" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Arquivo de migracao encontrado localmente" -ForegroundColor Green
Write-Host ""

# Verificar se o arquivo esta no servidor
Write-Host "Verificando se o arquivo esta no servidor..." -ForegroundColor Yellow

$checkCmd = "test -f " + $PROJECT_DIR + "/" + $MIGRATION_FILE
$result = ssh $SERVER $checkCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "Arquivo nao encontrado no servidor. Fazendo upload..." -ForegroundColor Yellow
    Write-Host ""
    
    # Criar diretorio se nao existir
    ssh $SERVER "mkdir -p $PROJECT_DIR/supabase/migrations"
    
    # Fazer upload do arquivo
    scp $MIGRATION_FILE "${SERVER}:${PROJECT_DIR}/supabase/migrations/"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao enviar arquivo" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "OK: Arquivo enviado com sucesso!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "OK: Arquivo ja existe no servidor" -ForegroundColor Green
    Write-Host ""
}

# Buscar container do Supabase
Write-Host "Buscando container do Supabase..." -ForegroundColor Yellow
$findCmd = "docker ps -q -f name=supabase-db"
$containerId = ssh $SERVER $findCmd

if ([string]::IsNullOrWhiteSpace($containerId)) {
    Write-Host "Aviso: Container 'supabase-db' nao encontrado. Listando containers..." -ForegroundColor Yellow
    ssh $SERVER "docker ps --format 'table {{.Names}}\t{{.Status}}'"
    Write-Host ""
    Write-Host "Execute manualmente:" -ForegroundColor Yellow
    Write-Host "  ssh $SERVER" -ForegroundColor White
    Write-Host "  cd $PROJECT_DIR" -ForegroundColor White
    Write-Host "  docker exec -i supabase-db psql -U postgres -d postgres < $MIGRATION_FILE" -ForegroundColor White
    exit 1
}

Write-Host "OK: Container encontrado: $containerId" -ForegroundColor Green
Write-Host ""

# Executar migracao
Write-Host "Executando SQL..." -ForegroundColor Cyan
$migrationPath = $PROJECT_DIR + "/" + $MIGRATION_FILE
$execCmd = "cat " + $migrationPath + " | docker exec -i " + $containerId + " psql -U postgres -d postgres"
ssh $SERVER $execCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "OK: Migracao executada com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximos passos:" -ForegroundColor Cyan
    Write-Host "1. Verificar logs do servidor Node.js" -ForegroundColor White
    Write-Host "2. Testar DELETE de mensagem no Flutter" -ForegroundColor White
    Write-Host "3. Verificar se arquivos sao removidos do Storage" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "Erro ao executar migracao (codigo: $LASTEXITCODE)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tentando metodo alternativo..." -ForegroundColor Yellow
    Write-Host ""
    
    # Metodo alternativo: copiar arquivo para dentro do container
    Write-Host "Tentando metodo alternativo (copiar para container)..." -ForegroundColor Yellow
    $altCmd1 = "docker cp " + $migrationPath + " " + $containerId + ":/tmp/migration.sql"
    $altCmd2 = "docker exec -i " + $containerId + " psql -U postgres -d postgres -f /tmp/migration.sql"
    $altCmd3 = "docker exec " + $containerId + " rm /tmp/migration.sql"
    
    ssh $SERVER $altCmd1
    if ($LASTEXITCODE -eq 0) {
        ssh $SERVER $altCmd2
        if ($LASTEXITCODE -eq 0) {
            ssh $SERVER $altCmd3
            Write-Host ""
            Write-Host "OK: Migracao executada com sucesso (metodo alternativo)!" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "Erro ao executar SQL no container" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host ""
        Write-Host "Erro ao copiar arquivo para container" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Concluido!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
