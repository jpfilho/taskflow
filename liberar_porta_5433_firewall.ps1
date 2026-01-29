# Script para liberar porta 5433 no firewall
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Liberar Porta 5433 no Firewall" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar qual firewall esta sendo usado
Write-Host "[1/3] Verificando firewall..." -ForegroundColor Yellow
$firewallType = ssh ${SERVER_USER}@${SERVER_IP} "which ufw >/dev/null 2>&1 && echo 'ufw' || (which firewall-cmd >/dev/null 2>&1 && echo 'firewalld' || echo 'none') 2>&1"
Write-Host "Tipo de firewall: $firewallType" -ForegroundColor Gray

# Liberar porta 5433
Write-Host ""
Write-Host "[2/3] Liberando porta 5433..." -ForegroundColor Yellow

if ($firewallType -match "ufw") {
    Write-Host "Usando UFW..." -ForegroundColor Gray
    Write-Host "Adicionando regra para porta 5433..." -ForegroundColor Yellow
    $addResult = ssh ${SERVER_USER}@${SERVER_IP} "ufw allow 5433/tcp 2>&1"
    Write-Host $addResult -ForegroundColor Gray
    
    Write-Host "Verificando regra adicionada..." -ForegroundColor Yellow
    $result = ssh ${SERVER_USER}@${SERVER_IP} "ufw status | grep 5433 2>&1"
    Write-Host $result -ForegroundColor Gray
    
    if ($result -match "5433") {
        Write-Host "SUCESSO: Porta 5433 liberada no UFW!" -ForegroundColor Green
    } else {
        Write-Host "ERRO: Nao foi possivel confirmar se porta foi liberada" -ForegroundColor Red
        Write-Host "Tente executar manualmente: ssh $SERVER_USER@$SERVER_IP 'ufw allow 5433/tcp'" -ForegroundColor Yellow
    }
} elseif ($firewallType -match "firewalld") {
    Write-Host "Usando firewalld..." -ForegroundColor Gray
    Write-Host "Adicionando regra permanente para porta 5433..." -ForegroundColor Yellow
    $addResult = ssh ${SERVER_USER}@${SERVER_IP} "firewall-cmd --permanent --add-port=5433/tcp 2>&1"
    Write-Host $addResult -ForegroundColor Gray
    
    Write-Host "Recarregando firewall..." -ForegroundColor Yellow
    $reloadResult = ssh ${SERVER_USER}@${SERVER_IP} "firewall-cmd --reload 2>&1"
    Write-Host $reloadResult -ForegroundColor Gray
    
    Write-Host "Verificando regra adicionada..." -ForegroundColor Yellow
    $result = ssh ${SERVER_USER}@${SERVER_IP} "firewall-cmd --list-ports | grep 5433 2>&1"
    Write-Host $result -ForegroundColor Gray
    
    if ($result -match "5433") {
        Write-Host "SUCESSO: Porta 5433 liberada no firewalld!" -ForegroundColor Green
    } else {
        Write-Host "ERRO: Nao foi possivel confirmar se porta foi liberada" -ForegroundColor Red
        Write-Host "Tente executar manualmente: ssh $SERVER_USER@$SERVER_IP 'firewall-cmd --permanent --add-port=5433/tcp && firewall-cmd --reload'" -ForegroundColor Yellow
    }
} else {
    Write-Host "AVISO: Nenhum firewall detectado ou firewall nao suportado" -ForegroundColor Yellow
    Write-Host "Verifique manualmente se ha firewall bloqueando a porta 5433" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Comandos manuais:" -ForegroundColor Yellow
    Write-Host "  UFW: ssh $SERVER_USER@$SERVER_IP 'ufw allow 5433/tcp'" -ForegroundColor White
    Write-Host "  Firewalld: ssh $SERVER_USER@$SERVER_IP 'firewall-cmd --permanent --add-port=5433/tcp && firewall-cmd --reload'" -ForegroundColor White
}

# Verificar se foi liberada
Write-Host ""
Write-Host "[3/3] Verificando se porta foi liberada..." -ForegroundColor Yellow
if ($firewallType -match "ufw") {
    $check = ssh ${SERVER_USER}@${SERVER_IP} "ufw status | grep 5433 2>&1"
} elseif ($firewallType -match "firewalld") {
    $check = ssh ${SERVER_USER}@${SERVER_IP} "firewall-cmd --list-ports | grep 5433 2>&1"
} else {
    $check = "N/A"
}

if ($check -match "5433") {
    Write-Host "SUCESSO: Porta 5433 esta liberada!" -ForegroundColor Green
    Write-Host "Regra: $check" -ForegroundColor Gray
} else {
    Write-Host "AVISO: Nao foi possivel confirmar se porta foi liberada" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Proximo Passo:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Agora teste a conexao no N8N novamente!" -ForegroundColor White
Write-Host "Se ainda nao funcionar, execute:" -ForegroundColor Yellow
Write-Host "  .\diagnosticar_conexao_n8n.ps1" -ForegroundColor White
Write-Host ""
