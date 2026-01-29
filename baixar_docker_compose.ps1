# Script para baixar docker-compose.yml para edicao local
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$COMPOSE_PATH = "/root/supabase/docker/docker-compose.yml"
$LOCAL_FILE = "docker-compose-supabase.yml"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Baixar docker-compose.yml" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Baixando arquivo..." -ForegroundColor Yellow
scp ${SERVER_USER}@${SERVER_IP}:${COMPOSE_PATH} $LOCAL_FILE

if (Test-Path $LOCAL_FILE) {
    Write-Host "Arquivo baixado: $LOCAL_FILE" -ForegroundColor Green
    Write-Host ""
    Write-Host "INSTRUCOES:" -ForegroundColor Yellow
    Write-Host "1. Edite o arquivo $LOCAL_FILE" -ForegroundColor White
    Write-Host "2. Adicione apos 'supabase-db:'" -ForegroundColor White
    Write-Host "   ports:" -ForegroundColor Gray
    Write-Host '     - "5432:5432"' -ForegroundColor Gray
    Write-Host "3. Execute: .\enviar_docker_compose.ps1" -ForegroundColor White
} else {
    Write-Host "Erro ao baixar arquivo" -ForegroundColor Red
}
