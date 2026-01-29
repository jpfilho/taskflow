# Script para desabilitar cookie seguro do N8N (permitir acesso via HTTP)
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$N8N_PORT = "5678"
$N8N_DATA_DIR = "/opt/n8n"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Corrigindo Cookie Seguro do N8N" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Parar o container
Write-Host "[1/3] Parando container N8N..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "docker stop n8n"
Start-Sleep -Seconds 2

# Remover container antigo
Write-Host ""
Write-Host "[2/3] Removendo container antigo..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "docker rm n8n"

# Recriar container com N8N_SECURE_COOKIE=false
Write-Host ""
Write-Host "[3/3] Recriando container com cookie seguro desabilitado..." -ForegroundColor Yellow
$dockerCommand = "docker run -d --name n8n --restart unless-stopped -p 5678:5678 -v ${N8N_DATA_DIR}:/home/node/.n8n -e N8N_BASIC_AUTH_ACTIVE=true -e N8N_BASIC_AUTH_USER=admin -e N8N_BASIC_AUTH_PASSWORD=n8n_admin_2026 -e N8N_HOST=212.85.0.249 -e N8N_PORT=5678 -e N8N_PROTOCOL=http -e N8N_SECURE_COOKIE=false -e WEBHOOK_URL=http://212.85.0.249:5678/ n8nio/n8n:latest"
ssh ${SERVER_USER}@${SERVER_IP} $dockerCommand
Start-Sleep -Seconds 5

# Verificar status
Write-Host ""
Write-Host "Verificando status do container..." -ForegroundColor Yellow
$status = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=n8n' --format '{{.Names}} - {{.Status}} - {{.Ports}}'"
Write-Host $status -ForegroundColor Gray

# Verificar logs
Write-Host ""
Write-Host "Ultimas linhas dos logs:" -ForegroundColor Yellow
$logs = ssh ${SERVER_USER}@${SERVER_IP} "docker logs n8n --tail 5 2>&1"
Write-Host $logs -ForegroundColor Gray

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Correcao Concluida!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Agora voce pode acessar via HTTP:" -ForegroundColor Yellow
Write-Host "  http://${SERVER_IP}:${N8N_PORT}" -ForegroundColor White
Write-Host ""
Write-Host "Credenciais:" -ForegroundColor Yellow
Write-Host "  Usuario: admin" -ForegroundColor White
Write-Host "  Senha: n8n_admin_2026" -ForegroundColor White
Write-Host ""
