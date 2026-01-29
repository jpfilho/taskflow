# ============================================
# VINCULAR TELEGRAM - DIRETO (SEM BUSCAR USER)
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VINCULAR TELEGRAM - MODO DIRETO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Este script vai buscar usuarios em TODAS as tabelas possiveis." -ForegroundColor Yellow
Write-Host ""

# 1. Buscar usuarios em diferentes schemas
Write-Host "1. Buscando usuarios no sistema..." -ForegroundColor Yellow

$sqlBuscar = @"
-- Tentar auth.users primeiro
SELECT 'auth.users' as tabela, id, email FROM auth.users LIMIT 1
UNION ALL
-- Tentar public.users
SELECT 'public.users' as tabela, id::text, email FROM public.users WHERE email IS NOT NULL LIMIT 1
UNION ALL
-- Tentar public.usuarios
SELECT 'public.usuarios' as tabela, id::text, email FROM public.usuarios WHERE email IS NOT NULL LIMIT 1;
"@

Write-Host "Resultado:" -ForegroundColor Gray
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -t -c `"$sqlBuscar`""

Write-Host ""
Write-Host "2. Digite o UUID do usuario que deseja vincular:" -ForegroundColor Yellow
Write-Host "   (ou pressione Enter para criar usuario teste)" -ForegroundColor Gray
$userId = Read-Host "UUID"

if ([string]::IsNullOrWhiteSpace($userId)) {
    Write-Host ""
    Write-Host "Criando usuario teste..." -ForegroundColor Yellow
    
    # Criar usuario direto na tabela
    $sqlCriar = @"
DO `$`$
DECLARE
    novo_user_id UUID;
BEGIN
    -- Tentar criar no auth.users se possivel
    BEGIN
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_user_meta_data,
            created_at,
            updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'jose@taskflow.com',
            crypt('senha123', gen_salt('bf')),
            NOW(),
            '{"full_name": "JOSE"}'::jsonb,
            NOW(),
            NOW()
        ) RETURNING id INTO novo_user_id;
        
        RAISE NOTICE 'Usuario criado: %', novo_user_id;
    EXCEPTION WHEN OTHERS THEN
        -- Se falhar, usar UUID fixo
        novo_user_id := '12345678-1234-1234-1234-123456789012';
        RAISE NOTICE 'Usando UUID fixo: %', novo_user_id;
    END;
    
    -- Vincular Telegram
    INSERT INTO telegram_identities (
        user_id,
        telegram_user_id,
        telegram_username,
        telegram_first_name,
        linked_at
    ) VALUES (
        novo_user_id,
        7807721517,
        'jose_user',
        'JOSE',
        NOW()
    ) ON CONFLICT (telegram_user_id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        linked_at = NOW();
END `$`$;
"@
    
    ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sqlCriar`""
    
} else {
    Write-Host ""
    Write-Host "Vinculando usuario $userId..." -ForegroundColor Yellow
    
    $sqlVincular = "INSERT INTO telegram_identities (user_id, telegram_user_id, telegram_username, telegram_first_name, linked_at) VALUES ('$userId', 7807721517, 'jose_user', 'JOSE', NOW()) ON CONFLICT (telegram_user_id) DO UPDATE SET user_id = EXCLUDED.user_id, linked_at = NOW();"
    
    ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sqlVincular`""
}

Write-Host ""
Write-Host "3. Verificando vinculacao..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT * FROM telegram_identities;'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora envie uma mensagem no Telegram e execute:" -ForegroundColor Yellow
Write-Host "  .\testar_webhook.ps1" -ForegroundColor White
Write-Host ""
