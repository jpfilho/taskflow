# ============================================
# DIAGNOSTICAR INTEGRACAO TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando subscriptions no banco..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT COUNT(*) as total, active FROM telegram_subscriptions GROUP BY active;'"

Write-Host ""
Write-Host "2. Verificando mensagens recentes no banco..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT id, source, conteudo, created_at FROM mensagens ORDER BY created_at DESC LIMIT 5;'"

Write-Host ""
Write-Host "3. Verificando logs do webhook..." -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 20 --no-pager | tail -20"

Write-Host ""
Write-Host "4. Verificando status do servico..." -ForegroundColor Yellow
ssh $SERVER "systemctl status telegram-webhook --no-pager | head -15"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
