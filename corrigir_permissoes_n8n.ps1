# Script para corrigir permissoes do diretorio N8N
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$N8N_DATA_DIR = "/opt/n8n"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Corrigindo Permissoes do N8N" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Parar o container
Write-Host "[1/5] Parando container N8N..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "docker stop n8n"
Start-Sleep -Seconds 2

# Corrigir permissoes do diretorio
Write-Host ""
Write-Host "[2/5] Corrigindo permissoes do diretorio ${N8N_DATA_DIR}..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "chown -R 1000:1000 ${N8N_DATA_DIR}"
ssh ${SERVER_USER}@${SERVER_IP} "chmod -R 755 ${N8N_DATA_DIR}"

# Verificar se o diretorio existe e tem as permissoes corretas
Write-Host ""
Write-Host "[3/5] Verificando permissoes..." -ForegroundColor Yellow
$checkPerms = ssh ${SERVER_USER}@${SERVER_IP} "ls -ld ${N8N_DATA_DIR}"
Write-Host "Permissoes: $checkPerms" -ForegroundColor Gray

# Remover e recriar o container com permissoes corretas
Write-Host ""
Write-Host "[4/5] Removendo container antigo..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "docker rm -f n8n 2>/dev/null; exit 0"

Write-Host ""
Write-Host "[5/5] Recriando container N8N com permissoes corretas..." -ForegroundColor Yellow
$dockerCommand = "docker run -d --name n8n --restart unless-stopped -p 5678:5678 -v ${N8N_DATA_DIR}:/home/node/.n8n -e N8N_BASIC_AUTH_ACTIVE=true -e N8N_BASIC_AUTH_USER=admin -e N8N_BASIC_AUTH_PASSWORD=n8n_admin_2026 -e N8N_HOST=212.85.0.249 -e N8N_PORT=5678 -e N8N_PROTOCOL=http -e WEBHOOK_URL=http://212.85.0.249:5678/ n8nio/n8n:latest"
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
$logs = ssh ${SERVER_USER}@${SERVER_IP} "docker logs n8n --tail 10 2>&1"
Write-Host $logs -ForegroundColor Gray

# Verificar se a porta esta sendo escutada
Write-Host ""
Write-Host "Verificando se a porta 5678 esta sendo escutada..." -ForegroundColor Yellow
$portCheck = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"netstat -tuln | grep 5678 || ss -tuln | grep 5678`""
if ($portCheck) {
    Write-Host "Porta 5678 esta sendo escutada:" -ForegroundColor Green
    Write-Host $portCheck -ForegroundColor Gray
} else {
    Write-Host "Porta ainda nao esta sendo escutada. Aguarde alguns segundos..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Correcao Concluida!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Aguarde alguns segundos e tente acessar:" -ForegroundColor Yellow
Write-Host "  http://${SERVER_IP}:5678" -ForegroundColor White
Write-Host ""
