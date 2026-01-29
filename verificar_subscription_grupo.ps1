# ============================================
# VERIFICAR SUBSCRIPTION DO GRUPO
# ============================================

$SERVER = "root@212.85.0.249"
$GRUPO_ID = "369377cf-3678-43e2-8314-f4accf58575f"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR SUBSCRIPTION" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Grupo ID: $GRUPO_ID" -ForegroundColor White
Write-Host ""

Write-Host "Buscando subscriptions para este grupo..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT id, thread_type, thread_id, telegram_chat_id, active FROM telegram_subscriptions WHERE thread_id = '$GRUPO_ID' AND active = true;\""

Write-Host ""
Write-Host "Verificando logs completos..." -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 30 --no-pager | tail -30"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
