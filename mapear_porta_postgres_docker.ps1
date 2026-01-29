# Script para mapear porta do Postgres Docker para o host
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$CONTAINER_NAME = "supabase-db"
$HOST_PORT = "5432"
$CONTAINER_PORT = "5432"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Mapear Porta Postgres Docker" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ATENÇÃO: Este script vai parar e recriar o container!" -ForegroundColor Yellow
Write-Host "Certifique-se de ter backup ou que o Supabase está usando volumes persistentes." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Deseja continuar? [S/N]"
if ($confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Operação cancelada." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "[1/4] Verificando container atual..." -ForegroundColor Yellow
$containerInfo = ssh ${SERVER_USER}@${SERVER_IP} "docker inspect $CONTAINER_NAME --format '{{.Name}} - {{.Image}}' 2>&1"
Write-Host $containerInfo -ForegroundColor Gray

Write-Host ""
Write-Host "[2/4] Obtendo configuração do container..." -ForegroundColor Yellow
$containerConfig = ssh ${SERVER_USER}@${SERVER_IP} "docker inspect $CONTAINER_NAME --format '{{json .}}' 2>&1"
Write-Host "Configuração obtida" -ForegroundColor Green

Write-Host ""
Write-Host "[3/4] Parando container..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "docker stop $CONTAINER_NAME"
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "[4/4] Recriando container com mapeamento de porta..." -ForegroundColor Yellow
Write-Host "NOTA: Este passo requer informações do container original." -ForegroundColor Yellow
Write-Host "Por favor, execute manualmente ou use docker-compose." -ForegroundColor Yellow
Write-Host ""
Write-Host "Comando sugerido (execute no servidor):" -ForegroundColor Cyan
Write-Host "docker start $CONTAINER_NAME" -ForegroundColor White
Write-Host ""
Write-Host "OU, se usar docker-compose:" -ForegroundColor Cyan
Write-Host "1. Edite o docker-compose.yml" -ForegroundColor White
Write-Host "2. Adicione na seção supabase-db:" -ForegroundColor White
Write-Host "   ports:" -ForegroundColor Gray
Write-Host "     - `"$HOST_PORT:$CONTAINER_PORT`"" -ForegroundColor Gray
Write-Host "3. Execute: docker-compose up -d" -ForegroundColor White
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Alternativa: Usar conexão interna" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se o N8N estiver rodando no mesmo servidor (212.85.0.249)," -ForegroundColor White
Write-Host "você pode conectar diretamente ao container usando:" -ForegroundColor White
Write-Host ""
Write-Host "  Host: supabase-db (nome do container)" -ForegroundColor Gray
Write-Host "  Port: 5432" -ForegroundColor Gray
Write-Host ""
Write-Host "OU" -ForegroundColor White
Write-Host ""
Write-Host "  Host: 127.0.0.1" -ForegroundColor Gray
Write-Host "  Port: 5432 (se mapeado)" -ForegroundColor Gray
Write-Host ""
