# ============================================
# CRIAR SUBSCRIPTION TELEGRAM - MANUAL
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CRIAR SUBSCRIPTION TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Pedir Chat ID
Write-Host "PASSO 1: Obter Chat ID" -ForegroundColor Yellow
Write-Host ""
Write-Host "Para obter o Chat ID do grupo Telegram:" -ForegroundColor White
Write-Host "  1. Adicione o bot @getidsbot ao grupo" -ForegroundColor Gray
Write-Host "  2. O bot vai mostrar o Chat ID (numero negativo)" -ForegroundColor Gray
Write-Host "  3. OU use: .\obter_chat_id_rapido.ps1" -ForegroundColor Gray
Write-Host ""

$chatId = Read-Host "Digite o Chat ID do grupo Telegram (ex: -1001234567890)"

if ([string]::IsNullOrWhiteSpace($chatId)) {
    Write-Host ""
    Write-Host "Chat ID nao fornecido!" -ForegroundColor Red
    exit
}

Write-Host "   Chat ID: $chatId" -ForegroundColor Green

# 2. Listar grupos disponiveis
Write-Host ""
Write-Host "PASSO 2: Selecionar grupo" -ForegroundColor Yellow
Write-Host ""
Write-Host "Grupos disponiveis:" -ForegroundColor White

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT id, tarefa_nome, created_at FROM grupos_chat ORDER BY created_at DESC LIMIT 10;'"

Write-Host ""
$grupoId = Read-Host "Digite o ID do grupo (UUID da primeira coluna)"

if ([string]::IsNullOrWhiteSpace($grupoId)) {
    Write-Host ""
    Write-Host "Grupo ID nao fornecido!" -ForegroundColor Red
    exit
}

Write-Host "   Grupo ID: $grupoId" -ForegroundColor Green

# 3. Criar subscription
Write-Host ""
Write-Host "PASSO 3: Criando subscription..." -ForegroundColor Yellow

$sql = @"
INSERT INTO telegram_subscriptions (
    thread_type,
    thread_id,
    mode,
    telegram_chat_id,
    telegram_topic_id,
    active
) VALUES (
    'TASK',
    '$grupoId',
    'group_plain',
    $chatId,
    NULL,
    true
) ON CONFLICT (thread_type, thread_id, telegram_chat_id, telegram_topic_id)
DO UPDATE SET
    active = true,
    updated_at = NOW()
RETURNING id;
"@

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sql`""

# 4. Verificar
Write-Host ""
Write-Host "PASSO 4: Verificando subscription..." -ForegroundColor Yellow

$sqlVerificar = @"
SELECT 
    ts.id,
    ts.thread_type,
    ts.telegram_chat_id,
    ts.active,
    gc.tarefa_nome
FROM telegram_subscriptions ts
LEFT JOIN grupos_chat gc ON gc.id = ts.thread_id
WHERE ts.telegram_chat_id = $chatId;
"@

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sqlVerificar`""

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "SUBSCRIPTION CRIADA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Chat ID Telegram: $chatId" -ForegroundColor White
Write-Host "Grupo ID Supabase: $grupoId" -ForegroundColor White
Write-Host ""
Write-Host "TESTE BIDIRECIONAL:" -ForegroundColor Yellow
Write-Host ""
Write-Host "TESTE 1 - Telegram para App:" -ForegroundColor Cyan
Write-Host "  1. Envie mensagem no grupo do Telegram" -ForegroundColor White
Write-Host "  2. Execute: .\verificar_mensagens_banco.ps1" -ForegroundColor Gray
Write-Host "  3. Abra o chat no app Flutter" -ForegroundColor Gray
Write-Host ""
Write-Host "TESTE 2 - App para Telegram:" -ForegroundColor Cyan
Write-Host "  1. Abra o chat no app Flutter" -ForegroundColor White
Write-Host "  2. Envie uma mensagem" -ForegroundColor Gray
Write-Host "  3. Verifique se aparece no Telegram" -ForegroundColor Gray
Write-Host ""
