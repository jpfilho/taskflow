# ============================================
# VERIFICAR FIREWALL E ACESSO EXTERNO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICANDO FIREWALL E ACESSO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando regras do UFW (firewall)..." -ForegroundColor Yellow
ssh $SERVER "ufw status"

Write-Host ""
Write-Host "2. Verificando iptables..." -ForegroundColor Yellow
ssh $SERVER "iptables -L -n | grep 8080"

Write-Host ""
Write-Host "3. Testando acesso externo com curl..." -ForegroundColor Yellow
curl -I http://212.85.0.249:8080/task2026/ 2>&1 | Select-String -Pattern "HTTP|Content|Location" | Select-Object -First 5

Write-Host ""
Write-Host "4. Verificando se a porta 8080 esta acessivel de fora..." -ForegroundColor Yellow
ssh $SERVER "netstat -tulpn | grep :8080"

Write-Host ""
Write-Host "5. Testando com telnet..." -ForegroundColor Yellow
$tcpClient = New-Object System.Net.Sockets.TcpClient
try {
    $tcpClient.Connect("212.85.0.249", 8080)
    $tcpClient.Close()
    Write-Host "   Porta 8080 ACESSIVEL!" -ForegroundColor Green
} catch {
    Write-Host "   Porta 8080 BLOQUEADA!" -ForegroundColor Red
    Write-Host "   Erro: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
