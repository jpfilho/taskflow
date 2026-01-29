# Script SIMPLES e DIRETO para mapear porta do supabase-db
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$COMPOSE_PATH = "/root/supabase/docker/docker-compose.yml"
$CONTAINER_NAME = "supabase-db"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Mapear Porta supabase-db - Versao Simples" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se ja esta mapeado
Write-Host "[1/3] Verificando porta..." -ForegroundColor Yellow
$hasMapping = ssh ${SERVER_USER}@${SERVER_IP} "docker port $CONTAINER_NAME 5432 2>&1"
if ($hasMapping -match "0\.0\.0\.0:" -or $hasMapping -match "\[::\]:") {
    Write-Host "Porta ja esta mapeada: $hasMapping" -ForegroundColor Green
    $portLine = ($hasMapping -split "`n")[0]
    if ($portLine -match "0\.0\.0\.0:(\d+)") {
        $mappedPort = $matches[1]
        Write-Host ""
        Write-Host "Use no N8N:" -ForegroundColor Yellow
        Write-Host "  Host: $SERVER_IP" -ForegroundColor White
        Write-Host "  Port: $mappedPort" -ForegroundColor White
        Write-Host "  Database: postgres" -ForegroundColor White
        Write-Host "  User: postgres" -ForegroundColor White
        Write-Host "  Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor White
    }
    exit 0
}

# Restaurar backup se necessario
Write-Host "[2/3] Preparando arquivo..." -ForegroundColor Yellow
$backupFile = ssh ${SERVER_USER}@${SERVER_IP} "ls -t $COMPOSE_PATH.backup_* 2>/dev/null | head -1"
if ($backupFile) {
    Write-Host "Restaurando backup mais recente..." -ForegroundColor Gray
    ssh ${SERVER_USER}@${SERVER_IP} "cp $backupFile $COMPOSE_PATH"
}

# Fazer novo backup
$newBackup = "$COMPOSE_PATH.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh ${SERVER_USER}@${SERVER_IP} "cp $COMPOSE_PATH $newBackup"
Write-Host "Backup criado: $newBackup" -ForegroundColor Green

# Adicionar mapeamento usando sed (mais confiavel)
Write-Host ""
Write-Host "[3/3] Adicionando mapeamento 5433:5432..." -ForegroundColor Yellow

# Usar sed para inserir apos 'restart: unless-stopped' na secao db
$sedResult = ssh ${SERVER_USER}@${SERVER_IP} "sed -i '/^  db:/,/^  [a-z]/ { /restart: unless-stopped/a\    ports:\n      - \"5433:5432\"\n  }' $COMPOSE_PATH 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Tentando metodo alternativo..." -ForegroundColor Yellow
    # Metodo alternativo: usar awk
    $awkResult = ssh ${SERVER_USER}@${SERVER_IP} "awk '/^  db:/ {print; getline; print; print \"    ports:\"; print \"      - \\\"5433:5432\\\"\"; next} 1' $COMPOSE_PATH > $COMPOSE_PATH.tmp && mv $COMPOSE_PATH.tmp $COMPOSE_PATH 2>&1"
}

# Verificar se foi adicionado
$verify = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 5 '^  db:' $COMPOSE_PATH | grep -A 2 'ports:' | grep '5433:5432'"
if ($verify) {
    Write-Host "Mapeamento adicionado!" -ForegroundColor Green
    
    # Validar
    $validate = ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose config -q 2>&1"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "docker-compose.yml valido!" -ForegroundColor Green
        
        # Reiniciar
        Write-Host ""
        Write-Host "Reiniciando container..." -ForegroundColor Yellow
        ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose up -d db"
        
        Start-Sleep -Seconds 3
        
        # Verificar porta
        $portCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker port $CONTAINER_NAME 5432 2>&1"
        if ($portCheck -match "5433") {
            Write-Host "Porta mapeada: $portCheck" -ForegroundColor Green
            Write-Host ""
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "CONFIGURACAO N8N:" -ForegroundColor Yellow
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Host: $SERVER_IP" -ForegroundColor White
            Write-Host "Port: 5433" -ForegroundColor White
            Write-Host "Database: postgres" -ForegroundColor White
            Write-Host "User: postgres" -ForegroundColor White
            Write-Host "Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor White
            Write-Host "SSL: Desabilitado" -ForegroundColor White
            Write-Host ""
        }
    } else {
        Write-Host "ERRO: docker-compose.yml invalido!" -ForegroundColor Red
        Write-Host "Restaurando backup..." -ForegroundColor Yellow
        ssh ${SERVER_USER}@${SERVER_IP} "cp $newBackup $COMPOSE_PATH"
        Write-Host ""
        Write-Host "EDITE MANUALMENTE:" -ForegroundColor Yellow
        Write-Host "  ssh $SERVER_USER@$SERVER_IP" -ForegroundColor White
        Write-Host "  nano $COMPOSE_PATH" -ForegroundColor White
        Write-Host "  Encontre a linha 'restart: unless-stopped' na secao 'db:'" -ForegroundColor White
        Write-Host "  Adicione logo apos:" -ForegroundColor White
        Write-Host "    ports:" -ForegroundColor Gray
        Write-Host "      - \"5433:5432\"" -ForegroundColor Gray
    }
} else {
    Write-Host "Falha ao adicionar mapeamento" -ForegroundColor Red
    Write-Host "Restaurando backup..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "cp $newBackup $COMPOSE_PATH"
    Write-Host ""
    Write-Host "EDITE MANUALMENTE:" -ForegroundColor Yellow
    Write-Host "  ssh $SERVER_USER@$SERVER_IP" -ForegroundColor White
    Write-Host "  nano $COMPOSE_PATH" -ForegroundColor White
    Write-Host "  Encontre a linha 'restart: unless-stopped' na secao 'db:'" -ForegroundColor White
    Write-Host "  Adicione logo apos:" -ForegroundColor White
    Write-Host "    ports:" -ForegroundColor Gray
    Write-Host "      - \"5433:5432\"" -ForegroundColor Gray
}
