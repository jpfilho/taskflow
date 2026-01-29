# ============================================
# REINICIAR WEBHOOK E VERIFICAR VINCULACAO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "REINICIAR WEBHOOK" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando vinculacao no banco..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT * FROM telegram_identities WHERE telegram_user_id = 7807721517;'"

Write-Host ""
Write-Host "2. Reiniciando servico..." -ForegroundColor Yellow
ssh $SERVER "systemctl restart telegram-webhook"

Write-Host ""
Write-Host "Aguardando 3 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "3. Verificando status..." -ForegroundColor Yellow
ssh $SERVER "systemctl status telegram-webhook --no-pager | head -15"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "WEBHOOK REINICIADO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora envie OUTRA mensagem no Telegram!" -ForegroundColor Yellow
Write-Host ""
