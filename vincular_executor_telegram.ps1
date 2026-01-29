# ============================================
# VINCULAR EXECUTOR 264259 AO TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VINCULAR EXECUTOR AO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Buscando executor com matricula 264259..." -ForegroundColor Yellow
Write-Host ""

# 1. Buscar o executor
$sqlBuscar = "SELECT id, nome, matricula, telefone FROM executores WHERE matricula = '264259';"

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sqlBuscar`""

Write-Host ""
Write-Host "Vinculando ao Telegram..." -ForegroundColor Yellow

# 2. Vincular
$sqlVincular = @"
DO `$`$
DECLARE
    executor_id UUID;
    executor_nome VARCHAR;
BEGIN
    -- Buscar executor
    SELECT id, nome INTO executor_id, executor_nome
    FROM executores 
    WHERE matricula = '264259';
    
    IF executor_id IS NULL THEN
        RAISE EXCEPTION 'Executor com matricula 264259 nao encontrado!';
    END IF;
    
    RAISE NOTICE 'Executor encontrado: % (ID: %)', executor_nome, executor_id;
    
    -- Vincular Telegram
    INSERT INTO telegram_identities (
        user_id,
        telegram_user_id,
        telegram_username,
        telegram_first_name,
        linked_at
    ) VALUES (
        executor_id,
        7807721517,
        'jose_user',
        'JOSE',
        NOW()
    ) ON CONFLICT (telegram_user_id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        telegram_first_name = EXCLUDED.telegram_first_name,
        linked_at = NOW();
    
    RAISE NOTICE 'Telegram vinculado com sucesso!';
END `$`$;
"@

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sqlVincular`""

Write-Host ""
Write-Host "Verificando vinculacao..." -ForegroundColor Yellow
Write-Host ""

$sqlVerificar = @"
SELECT 
    ti.telegram_user_id,
    ti.telegram_first_name,
    e.matricula,
    e.nome,
    e.telefone,
    ti.linked_at
FROM telegram_identities ti
JOIN executores e ON e.id = ti.user_id
WHERE ti.telegram_user_id = 7807721517;
"@

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sqlVerificar`""

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "VINCULACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Proximo passo:" -ForegroundColor Yellow
Write-Host "  1. Envie uma mensagem no Telegram: 'Ola TaskFlow!'" -ForegroundColor White
Write-Host "  2. Execute: .\testar_webhook.ps1" -ForegroundColor White
Write-Host "  3. Execute: .\verificar_mensagens_banco.ps1" -ForegroundColor White
Write-Host ""
Write-Host "A mensagem deve ser salva no banco com o executor vinculado!" -ForegroundColor Cyan
Write-Host ""
