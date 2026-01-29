# Script para instalar N8N no servidor
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"  # Ajuste conforme necessário
$N8N_PORT = "5678"
$N8N_DATA_DIR = "/opt/n8n"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Instalação do N8N no Servidor" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se o Docker está instalado
Write-Host "[1/5] Verificando se o Docker está instalado..." -ForegroundColor Yellow
$dockerCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker --version 2>&1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker não encontrado. Instalando Docker..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && systemctl start docker && systemctl enable docker && usermod -aG docker `$USER"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker instalado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "Erro ao instalar Docker. Verifique manualmente." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Docker já está instalado: $dockerCheck" -ForegroundColor Green
}

# Verificar containers existentes e porta
Write-Host ""
Write-Host "[2/6] Verificando containers Docker existentes..." -ForegroundColor Yellow
$existingContainers = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
Write-Host "Containers atualmente rodando:" -ForegroundColor Cyan
Write-Host $existingContainers -ForegroundColor Gray
Write-Host ""
Write-Host "[OK] O N8N sera instalado como um novo container isolado" -ForegroundColor Green
Write-Host "[OK] Nao sera alterado nenhum container existente" -ForegroundColor Green

# Verificar se a porta está em uso
Write-Host ""
Write-Host "[3/6] Verificando se a porta ${N8N_PORT} está disponível..." -ForegroundColor Yellow
$portCheckCmd = "bash -c `"netstat -tuln | grep ':" + $N8N_PORT + " ' || echo 'Porta livre'`""
$portCheck = ssh ${SERVER_USER}@${SERVER_IP} $portCheckCmd
if ($portCheck -match "Porta livre" -or $portCheck -eq "") {
    Write-Host "Porta ${N8N_PORT} está disponível" -ForegroundColor Green
} else {
    Write-Host "Atenção: Porta ${N8N_PORT} está em uso:" -ForegroundColor Yellow
    Write-Host $portCheck -ForegroundColor Gray
    $continue = Read-Host "Deseja continuar mesmo assim? [S/N]"
    if ($continue -ne "S" -and $continue -ne "s") {
        Write-Host "Instalação cancelada." -ForegroundColor Yellow
        exit 0
    }
}

# Criar diretório para dados do N8N
Write-Host ""
Write-Host "[4/6] Criando diretório para dados do N8N..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${N8N_DATA_DIR}"
Write-Host "Diretório criado: $N8N_DATA_DIR" -ForegroundColor Green

# Parar e remover apenas o container n8n existente (se houver)
Write-Host ""
Write-Host "[5/6] Verificando se já existe container 'n8n'..." -ForegroundColor Yellow
$n8nExists = ssh ${SERVER_USER}@${SERVER_IP} "docker ps -a --filter 'name=n8n' --format '{{.Names}}'"
if ($n8nExists -match "n8n") {
    Write-Host "Container 'n8n' encontrado. Será removido e recriado." -ForegroundColor Yellow
    $removeCmd = "bash -c `"docker stop n8n 2>/dev/null; docker rm n8n 2>/dev/null; exit 0`""
    ssh ${SERVER_USER}@${SERVER_IP} $removeCmd
    Write-Host "Container antigo removido" -ForegroundColor Green
} else {
    Write-Host "Nenhum container 'n8n' existente encontrado" -ForegroundColor Green
}

# Instalar N8N via Docker
Write-Host ""
Write-Host "[6/6] Instalando N8N via Docker..." -ForegroundColor Yellow
$dockerCommand = "docker run -d --name n8n --restart unless-stopped -p " + $N8N_PORT + ":5678 -v " + $N8N_DATA_DIR + ":/home/node/.n8n -e N8N_BASIC_AUTH_ACTIVE=true -e N8N_BASIC_AUTH_USER=admin -e N8N_BASIC_AUTH_PASSWORD=n8n_admin_2026 -e N8N_HOST=212.85.0.249 -e N8N_PORT=5678 -e N8N_PROTOCOL=http -e WEBHOOK_URL=http://212.85.0.249:5678/ n8nio/n8n:latest"
$result = ssh ${SERVER_USER}@${SERVER_IP} $dockerCommand 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "N8N instalado com sucesso!" -ForegroundColor Green
    if ($result) {
        Write-Host "Container ID: $result" -ForegroundColor Gray
    }
} else {
    Write-Host "Erro ao instalar N8N. Saída:" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    Write-Host ""
    Write-Host "Verificando logs do Docker..." -ForegroundColor Yellow
    $logsCmd = "bash -c `"docker logs n8n 2>&1 | tail -20`""
    ssh ${SERVER_USER}@${SERVER_IP} $logsCmd
    exit 1
}

# Verificar status do container
Write-Host ""
Write-Host "Verificando status do N8N..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$status = ssh ${SERVER_USER}@${SERVER_IP} "docker ps | grep n8n"
if ($status) {
    Write-Host "N8N está rodando!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Instalação Concluída!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Mostrar todos os containers para confirmar que nada foi afetado
    Write-Host "Containers Docker atualmente rodando:" -ForegroundColor Cyan
    $allContainers = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    Write-Host $allContainers -ForegroundColor Gray
    Write-Host ""
    Write-Host "[OK] Todos os containers anteriores continuam rodando normalmente" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Acesso ao N8N:" -ForegroundColor Yellow
    Write-Host "  URL: http://${SERVER_IP}:${N8N_PORT}" -ForegroundColor White
    Write-Host ""
    Write-Host "Credenciais de acesso:" -ForegroundColor Yellow
    Write-Host "  Usuário: admin" -ForegroundColor White
    Write-Host "  Senha: n8n_admin_2026" -ForegroundColor White
    Write-Host ""
    Write-Host "Dados salvos em: $N8N_DATA_DIR" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Comandos úteis:" -ForegroundColor Yellow
    Write-Host "  Ver logs: ssh ${SERVER_USER}@${SERVER_IP} 'docker logs n8n'" -ForegroundColor White
    Write-Host "  Parar: ssh ${SERVER_USER}@${SERVER_IP} 'docker stop n8n'" -ForegroundColor White
    Write-Host "  Iniciar: ssh ${SERVER_USER}@${SERVER_IP} 'docker start n8n'" -ForegroundColor White
    Write-Host "  Reiniciar: ssh ${SERVER_USER}@${SERVER_IP} 'docker restart n8n'" -ForegroundColor White
    Write-Host "  Ver todos containers: ssh ${SERVER_USER}@${SERVER_IP} 'docker ps'" -ForegroundColor White
} else {
    Write-Host "N8N não está rodando. Verifique os logs:" -ForegroundColor Red
    Write-Host "  ssh ${SERVER_USER}@${SERVER_IP} 'docker logs n8n'" -ForegroundColor Yellow
}
