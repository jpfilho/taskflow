# Script para testar se a porta 5433 esta acessivel externamente
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testar Conexao Externa Porta 5433" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Testando conexao TCP para $SERVER_IP:5433..." -ForegroundColor Yellow
Write-Host ""

# Tentar conexao TCP usando Test-NetConnection (PowerShell nativo)
try {
    $test = Test-NetConnection -ComputerName $SERVER_IP -Port 5433 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($test) {
        Write-Host "SUCESSO: Porta 5433 esta acessivel externamente!" -ForegroundColor Green
        Write-Host ""
        Write-Host "A conexao do N8N deve funcionar agora." -ForegroundColor White
        Write-Host "Teste novamente no N8N." -ForegroundColor White
    } else {
        Write-Host "ERRO: Porta 5433 NAO esta acessivel externamente!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Possiveis causas:" -ForegroundColor Yellow
        Write-Host "1. Firewall ainda bloqueando (execute: .\liberar_porta_5433_firewall.ps1)" -ForegroundColor White
        Write-Host "2. Firewall do provedor/hosting bloqueando" -ForegroundColor White
        Write-Host "3. N8N esta em rede diferente e nao tem acesso" -ForegroundColor White
    }
} catch {
    Write-Host "ERRO ao testar conexao: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tente executar manualmente:" -ForegroundColor Yellow
    Write-Host "  Test-NetConnection -ComputerName $SERVER_IP -Port 5433" -ForegroundColor White
}

Write-Host ""
