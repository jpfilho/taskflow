# Script para enviar docker-compose.yml editado de volta ao servidor
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$COMPOSE_PATH = "/root/supabase/docker/docker-compose.yml"
$LOCAL_FILE = "docker-compose-supabase.yml"

if (-not (Test-Path $LOCAL_FILE)) {
    Write-Host "Arquivo $LOCAL_FILE nao encontrado!" -ForegroundColor Red
    Write-Host "Execute primeiro: .\baixar_docker_compose.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Enviar docker-compose.yml" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Fazer backup no servidor
Write-Host "Fazendo backup no servidor..." -ForegroundColor Yellow
$backupFile = "$COMPOSE_PATH.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh ${SERVER_USER}@${SERVER_IP} "cp $COMPOSE_PATH $backupFile"
Write-Host "Backup: $backupFile" -ForegroundColor Green

# Enviar arquivo
Write-Host "Enviando arquivo..." -ForegroundColor Yellow
scp $LOCAL_FILE ${SERVER_USER}@${SERVER_IP}:${COMPOSE_PATH}

# Reiniciar container
Write-Host "Reiniciando container..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose up -d supabase-db"

Start-Sleep -Seconds 3

# Verificar porta
Write-Host "Verificando porta..." -ForegroundColor Yellow
$portCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker port supabase-db 5432 2>&1"
if ($portCheck -match "5432") {
    Write-Host "Porta mapeada: $portCheck" -ForegroundColor Green
} else {
    Write-Host "Verifique manualmente: docker port supabase-db" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Concluido!" -ForegroundColor Green
