# ============================================
# CADASTRAR SUPERGRUPO - MODO INTERATIVO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CADASTRAR SUPERGRUPO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este script irá:" -ForegroundColor Yellow
Write-Host "  1. Listar comunidades disponíveis" -ForegroundColor White
Write-Host "  2. Permitir escolher uma comunidade" -ForegroundColor White
Write-Host "  3. Solicitar o Telegram Chat ID" -ForegroundColor White
Write-Host "  4. Cadastrar o supergrupo" -ForegroundColor White
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp cadastrar_community_interativo.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando script interativo..." -ForegroundColor Yellow
Write-Host "⚠️  Você precisará interagir com o script no servidor" -ForegroundColor Yellow
Write-Host ""
ssh -t $SERVER "chmod +x /root/cadastrar_community_interativo.sh && /root/cadastrar_community_interativo.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
