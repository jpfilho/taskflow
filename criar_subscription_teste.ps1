# ============================================
# CRIAR SUBSCRIPTION DE TESTE
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CRIAR SUBSCRIPTION TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "ATENCAO:" -ForegroundColor Yellow
Write-Host "  Antes de executar, voce precisa:" -ForegroundColor White
Write-Host "  1. Saber o CHAT_ID do grupo Telegram" -ForegroundColor White
Write-Host "  2. Ter um grupo criado no sistema" -ForegroundColor White
Write-Host ""

Write-Host "Execute primeiro:" -ForegroundColor Cyan
Write-Host "  .\obter_chat_id_dos_logs.ps1  (ver chat_id)" -ForegroundColor Gray
Write-Host "  .\listar_grupos.ps1           (ver grupos)" -ForegroundColor Gray
Write-Host ""

$chatId = Read-Host "Digite o CHAT_ID do Telegram (ex: -1001234567890)"
$grupoId = Read-Host "Digite o ID do grupo no sistema (UUID)"

if ([string]::IsNullOrWhiteSpace($chatId) -or [string]::IsNullOrWhiteSpace($grupoId)) {
    Write-Host ""
    Write-Host "Valores obrigatorios nao fornecidos!" -ForegroundColor Red
    Write-Host ""
    exit
}

Write-Host ""
Write-Host "Criando subscription..." -ForegroundColor Yellow

$sql = @"
INSERT INTO telegram_subscriptions (
    thread_type,
    thread_id,
    mode,
    telegram_chat_id,
    telegram_topic_id,
    active,
    settings
) VALUES (
    'TASK',
    '$grupoId',
    'group_plain',
    $chatId,
    NULL,
    true,
    '{"send_notifications": true, "bi_directional": true}'::jsonb
) ON CONFLICT (thread_type, thread_id, telegram_chat_id, telegram_topic_id)
DO UPDATE SET
    active = true,
    updated_at = NOW();

-- Verificar
SELECT 
    id,
    thread_type,
    thread_id,
    telegram_chat_id,
    active,
    created_at
FROM telegram_subscriptions
WHERE telegram_chat_id = $chatId;
"@

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sql`""

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "SUBSCRIPTION CRIADA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora envie outra mensagem no Telegram!" -ForegroundColor Yellow
Write-Host ""
