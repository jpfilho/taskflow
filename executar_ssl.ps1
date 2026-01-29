# ============================================
# EXECUTAR CONFIGURACAO SSL
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CONFIGURANDO SSL PARA TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "IMPORTANTE: Antes de continuar, edite o arquivo:" -ForegroundColor Yellow
Write-Host "   configurar_ssl_telegram.sh" -ForegroundColor White
Write-Host ""
Write-Host "Altere a linha:" -ForegroundColor Yellow
Write-Host '   EMAIL="seu-email@exemplo.com"' -ForegroundColor Gray
Write-Host ""
Write-Host "Para seu email valido (necessario para Let's Encrypt)" -ForegroundColor Yellow
Write-Host ""
Write-Host -NoNewline "Pressione ENTER para continuar ou Ctrl+C para cancelar... " -ForegroundColor Cyan
$null = Read-Host

Write-Host ""
Write-Host "1. Verificando porta 80 (necessaria para Let's Encrypt)..." -ForegroundColor Yellow
ssh $SERVER "ufw allow 80/tcp"
ssh $SERVER "ufw allow 443/tcp"

Write-Host ""
Write-Host "2. Copiando script para o servidor..." -ForegroundColor Yellow
scp configurar_ssl_telegram.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "3. Executando configuracao SSL no servidor..." -ForegroundColor Yellow
Write-Host "   (Isso pode demorar alguns minutos)" -ForegroundColor Gray
Write-Host ""
ssh $SERVER "chmod +x /root/configurar_ssl_telegram.sh && /root/configurar_ssl_telegram.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Configuracao concluida!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Teste no navegador:" -ForegroundColor Cyan
Write-Host "   https://api.taskflowv3.com.br/" -ForegroundColor Yellow
Write-Host ""
