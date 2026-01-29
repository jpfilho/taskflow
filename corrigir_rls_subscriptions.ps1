# ============================================
# CORRIGIR RLS DA TABELA telegram_subscriptions
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR RLS DA TABELA telegram_subscriptions" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp corrigir_rls_subscriptions.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando correção..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/corrigir_rls_subscriptions.sh && /root/corrigir_rls_subscriptions.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CORREÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora teste novamente enviando uma mensagem do Flutter!" -ForegroundColor Yellow
Write-Host ""
