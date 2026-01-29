# ============================================
# VINCULAR USUARIO TELEGRAM MANUALMENTE
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VINCULAR USUARIO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Usuario detectado nos logs:" -ForegroundColor Yellow
Write-Host "  Nome: JOSE" -ForegroundColor White
Write-Host "  Telegram ID: 7807721517" -ForegroundColor White
Write-Host ""

# Solicitar o User ID do Supabase
Write-Host "Para vincular, preciso do UUID do usuario no Supabase." -ForegroundColor Yellow
Write-Host ""
Write-Host "Como obter o UUID:" -ForegroundColor Cyan
Write-Host "  1. Acesse: http://212.85.0.249:8000/project/default/auth/users" -ForegroundColor Gray
Write-Host "  2. Procure pelo usuario 'JOSE'" -ForegroundColor Gray
Write-Host "  3. Copie o UUID (ex: 123e4567-e89b-12d3-a456-426614174000)" -ForegroundColor Gray
Write-Host ""

$userId = Read-Host "Cole o UUID do usuario aqui"

if ($userId -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
    Write-Host ""
    Write-Host "Vinculando usuario no banco..." -ForegroundColor Yellow
    
    $sql = @"
INSERT INTO telegram_identities (user_id, telegram_user_id, telegram_username, telegram_first_name, linked_at)
VALUES ('$userId', 7807721517, 'jose_user', 'JOSE', NOW())
ON CONFLICT (telegram_user_id) 
DO UPDATE SET 
    user_id = EXCLUDED.user_id,
    telegram_username = EXCLUDED.telegram_username,
    telegram_first_name = EXCLUDED.telegram_first_name,
    linked_at = NOW();
"@
    
    ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sql`""
    
    Write-Host ""
    Write-Host "Usuario vinculado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Agora envie outra mensagem no Telegram e execute:" -ForegroundColor Yellow
    Write-Host "  .\testar_webhook.ps1" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "UUID invalido! Formato esperado:" -ForegroundColor Red
    Write-Host "  123e4567-e89b-12d3-a456-426614174000" -ForegroundColor Gray
    Write-Host ""
}
