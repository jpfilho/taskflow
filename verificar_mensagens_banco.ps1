# ============================================
# VERIFICAR MENSAGENS NO BANCO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MENSAGENS NO BANCO DE DADOS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Ultimas 10 mensagens:" -ForegroundColor Yellow
Write-Host ""

$sql = @"
SELECT 
    m.id,
    m.source,
    m.text,
    m.author_display,
    m.created_at,
    m.metadata->>'telegram_message_id' as tg_msg_id
FROM messages m
ORDER BY m.created_at DESC
LIMIT 10;
"@

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sql`""

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Identidades vinculadas:" -ForegroundColor Yellow
Write-Host ""

$sql2 = "SELECT user_id, telegram_user_id, telegram_first_name, linked_at FROM telegram_identities;"

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sql2`""

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
