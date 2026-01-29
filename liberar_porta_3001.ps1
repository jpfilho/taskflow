# ============================================
# LIBERAR PORTA 3001 NO FIREWALL
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "Liberando porta 3001 no firewall..." -ForegroundColor Cyan
Write-Host ""

# Verificar status do firewall
$firewallStatus = ssh $SERVER "ufw status 2>&1 | head -1"
Write-Host "Status do firewall: $firewallStatus" -ForegroundColor Yellow

# Liberar porta 3001
Write-Host "Liberando porta 3001..." -ForegroundColor Yellow
ssh $SERVER "ufw allow 3001/tcp comment 'Telegram webhook HTTP fallback'"

# Verificar se foi liberada
$portCheck = ssh $SERVER "ufw status | grep 3001"
if ($portCheck) {
    Write-Host "[OK] Porta 3001 liberada:" -ForegroundColor Green
    Write-Host $portCheck -ForegroundColor Gray
} else {
    Write-Host "[AVISO] Não foi possível verificar se a porta foi liberada" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Teste a conexão HTTP direta novamente:" -ForegroundColor Cyan
Write-Host "  .\testar_servidor_telegram_rapido.ps1" -ForegroundColor White
Write-Host ""
