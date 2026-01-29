# Script para liberar a porta 5678 no firewall para o N8N
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$N8N_PORT = "5678"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Liberando Porta ${N8N_PORT} no Firewall" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se a porta está aberta no firewall
Write-Host "[1/4] Verificando status da porta no firewall..." -ForegroundColor Yellow
$firewallCheck = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"ufw status | grep ${N8N_PORT} || iptables -L -n | grep ${N8N_PORT} || firewall-cmd --list-ports | grep ${N8N_PORT} || echo 'Porta nao encontrada nas regras'`""
Write-Host $firewallCheck -ForegroundColor Gray

# Tentar liberar com UFW (Ubuntu/Debian)
Write-Host ""
Write-Host "[2/4] Tentando liberar porta com UFW..." -ForegroundColor Yellow
$ufwCmd = "bash -c `"if command -v ufw &> /dev/null; then ufw allow ${N8N_PORT}/tcp && echo 'UFW: Porta liberada'; else echo 'UFW nao instalado'; fi`""
$ufwResult = ssh ${SERVER_USER}@${SERVER_IP} $ufwCmd
Write-Host $ufwResult -ForegroundColor Gray

# Tentar liberar com firewall-cmd (CentOS/RHEL)
Write-Host ""
Write-Host "[3/4] Tentando liberar porta com firewall-cmd..." -ForegroundColor Yellow
$firewallCmd = "bash -c `"if command -v firewall-cmd &> /dev/null; then firewall-cmd --permanent --add-port=${N8N_PORT}/tcp && firewall-cmd --reload && echo 'firewall-cmd: Porta liberada'; else echo 'firewall-cmd nao instalado'; fi`""
$firewallCmdResult = ssh ${SERVER_USER}@${SERVER_IP} $firewallCmd
Write-Host $firewallCmdResult -ForegroundColor Gray

# Tentar liberar com iptables diretamente
Write-Host ""
Write-Host "[4/4] Tentando liberar porta com iptables..." -ForegroundColor Yellow
$iptablesCmd = "bash -c `"iptables -I INPUT -p tcp --dport ${N8N_PORT} -j ACCEPT 2>&1; iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null || echo 'Regra iptables adicionada'`""
$iptablesResult = ssh ${SERVER_USER}@${SERVER_IP} $iptablesCmd
Write-Host $iptablesResult -ForegroundColor Gray

# Verificar se o container está realmente rodando e escutando na porta
Write-Host ""
Write-Host "Verificando se o container N8N esta escutando na porta..." -ForegroundColor Yellow
$portListen = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"netstat -tuln | grep ${N8N_PORT} || ss -tuln | grep ${N8N_PORT}`""
if ($portListen) {
    Write-Host "Porta ${N8N_PORT} esta sendo escutada:" -ForegroundColor Green
    Write-Host $portListen -ForegroundColor Gray
} else {
    Write-Host "ATENCAO: Porta ${N8N_PORT} nao esta sendo escutada!" -ForegroundColor Red
    Write-Host "Verificando logs do container..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "docker logs n8n --tail 30"
}

# Verificar status do container
Write-Host ""
Write-Host "Status do container N8N:" -ForegroundColor Yellow
$containerStatus = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=n8n' --format '{{.Names}} - {{.Status}} - {{.Ports}}'"
Write-Host $containerStatus -ForegroundColor Gray

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verificacao Concluida!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tente acessar novamente:" -ForegroundColor Yellow
Write-Host "  http://${SERVER_IP}:${N8N_PORT}" -ForegroundColor White
Write-Host ""
Write-Host "Se ainda nao funcionar, verifique:" -ForegroundColor Yellow
Write-Host "  1. Firewall do provedor/cloud (se aplicavel)" -ForegroundColor White
Write-Host "  2. Logs do container: ssh ${SERVER_USER}@${SERVER_IP} 'docker logs n8n'" -ForegroundColor White
Write-Host "  3. Se o container esta realmente rodando: ssh ${SERVER_USER}@${SERVER_IP} 'docker ps | grep n8n'" -ForegroundColor White
Write-Host ""
