# ============================================
# DEPLOY TELEGRAM WEBHOOK - WINDOWS
# ============================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DEPLOY TELEGRAM WEBHOOK NODE.JS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Executando deploy no servidor..." -ForegroundColor Yellow
Write-Host ""

# Tornar o script bash executável e executar
bash ./deploy_telegram_webhook.sh

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMO PASSO:" -ForegroundColor Yellow
Write-Host "   Teste enviando uma mensagem no Telegram!" -ForegroundColor White
Write-Host ""
Write-Host "Para ver os logs:" -ForegroundColor Cyan
Write-Host "   ssh root@212.85.0.249 'journalctl -u telegram-webhook -f'" -ForegroundColor White
Write-Host ""
