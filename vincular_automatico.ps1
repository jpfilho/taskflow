# ============================================
# VINCULAR AUTOMATICAMENTE (USUARIO ROOT)
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VINCULACAO AUTOMATICA - USUARIO ROOT" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Este script vincula o usuario ROOT automaticamente." -ForegroundColor Yellow
Write-Host "Usuario do Telegram: JOSE (ID: 7807721517)" -ForegroundColor White
Write-Host ""

$confirma = Read-Host "Vincular agora? (S/N)"

if ($confirma -eq "S" -or $confirma -eq "s") {
    Write-Host ""
    Write-Host "Vinculando..." -ForegroundColor Yellow
    
    $sql = @"
DO `$`$
DECLARE
    root_user_id UUID;
BEGIN
    -- Buscar o usuario root (primeiro admin)
    SELECT id INTO root_user_id 
    FROM auth.users 
    WHERE raw_user_meta_data->>'is_root' = 'true' 
       OR raw_user_meta_data->>'tipo' = 'root'
    LIMIT 1;
    
    -- Se nao encontrar, pegar o primeiro usuario
    IF root_user_id IS NULL THEN
        SELECT id INTO root_user_id FROM auth.users ORDER BY created_at LIMIT 1;
    END IF;
    
    -- Vincular
    INSERT INTO telegram_identities (user_id, telegram_user_id, telegram_username, telegram_first_name, linked_at)
    VALUES (root_user_id, 7807721517, 'jose_user', 'JOSE', NOW())
    ON CONFLICT (telegram_user_id) 
    DO UPDATE SET 
        user_id = EXCLUDED.user_id,
        telegram_username = EXCLUDED.telegram_username,
        telegram_first_name = EXCLUDED.telegram_first_name,
        linked_at = NOW();
    
    RAISE NOTICE 'Usuario vinculado: %', root_user_id;
END `$`$;
"@
    
    ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sql`""
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "VINCULADO COM SUCESSO!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximo passo:" -ForegroundColor Yellow
    Write-Host "  1. Envie uma mensagem no Telegram" -ForegroundColor White
    Write-Host "  2. Execute: .\testar_webhook.ps1" -ForegroundColor White
    Write-Host "  3. Verifique se a mensagem apareceu no banco!" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Cancelado." -ForegroundColor Gray
    Write-Host ""
}
