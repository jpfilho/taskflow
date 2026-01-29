# ============================================
# DIAGNOSTICAR CONEXAO SUPABASE
# ============================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICANDO SUPABASE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Testar HTTP (porta 8000)
Write-Host "1. Testando HTTP (porta 8000)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://212.85.0.249:8000" -Method Get -TimeoutSec 5
    Write-Host "   Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   HTTP funcionando!" -ForegroundColor Green
} catch {
    Write-Host "   ERRO: $_" -ForegroundColor Red
    Write-Host "   HTTP NAO esta acessivel!" -ForegroundColor Red
}

# 2. Testar HTTPS (porta 443)
Write-Host ""
Write-Host "2. Testando HTTPS..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://api.taskflowv3.com.br" -Method Get -TimeoutSec 5
    Write-Host "   Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "   HTTPS funcionando!" -ForegroundColor Green
} catch {
    Write-Host "   ERRO: $_" -ForegroundColor Red
}

# 3. Testar porta 8000 com telnet
Write-Host ""
Write-Host "3. Testando conectividade porta 8000..." -ForegroundColor Yellow
$tcpClient = New-Object System.Net.Sockets.TcpClient
try {
    $tcpClient.Connect("212.85.0.249", 8000)
    $tcpClient.Close()
    Write-Host "   Porta 8000 ACESSIVEL!" -ForegroundColor Green
} catch {
    Write-Host "   Porta 8000 BLOQUEADA ou servidor offline!" -ForegroundColor Red
}

# 4. Verificar no servidor
Write-Host ""
Write-Host "4. Verificando servidor remoto..." -ForegroundColor Yellow
ssh root@212.85.0.249 "docker ps | grep supabase-kong && netstat -tulpn | grep :8000"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICO COMPLETO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
