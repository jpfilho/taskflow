# ============================================
# CONFIGURACAO COMPLETA TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CONFIGURACAO COMPLETA TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Obtendo CHAT_ID dos logs..." -ForegroundColor Yellow
$chatIdOutput = ssh $SERVER "journalctl -u telegram-webhook -n 20 --no-pager | grep -oP '(?<=\""chat\"":)[^,}]*' | tail -1"
$chatId = $chatIdOutput.Trim()

if ([string]::IsNullOrWhiteSpace($chatId)) {
    Write-Host "   ERRO: Chat ID nao encontrado nos logs!" -ForegroundColor Red
    Write-Host "   Envie uma mensagem no Telegram primeiro!" -ForegroundColor Yellow
    exit
}

Write-Host "   Chat ID encontrado: $chatId" -ForegroundColor Green

Write-Host ""
Write-Host "2. Verificando grupos existentes..." -ForegroundColor Yellow
$gruposOutput = ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -t -c 'SELECT id FROM grupos_chat ORDER BY created_at DESC LIMIT 1;'"
$grupoId = $gruposOutput.Trim()

if ([string]::IsNullOrWhiteSpace($grupoId)) {
    Write-Host "   Nenhum grupo encontrado. Criando grupo de teste..." -ForegroundColor Yellow
    
    $sqlCriarGrupo = @"
INSERT INTO grupos_chat (nome, descricao, ativo, created_at, updated_at)
VALUES ('Grupo Telegram Teste', 'Grupo para teste de integracao Telegram', true, NOW(), NOW())
RETURNING id;
"@
    
    $grupoId = ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -t -c `"$sqlCriarGrupo`""
    $grupoId = $grupoId.Trim()
    Write-Host "   Grupo criado: $grupoId" -ForegroundColor Green
} else {
    Write-Host "   Grupo existente: $grupoId" -ForegroundColor Green
}

Write-Host ""
Write-Host "3. Criando subscription..." -ForegroundColor Yellow

$sqlSubscription = @"
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

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sqlSubscription`""

Write-Host ""
Write-Host "4. Verificando configuracao..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT ts.id, ts.thread_type, ts.telegram_chat_id, ts.active, gc.nome FROM telegram_subscriptions ts LEFT JOIN grupos_chat gc ON gc.id = ts.thread_id WHERE ts.telegram_chat_id = $chatId;'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CONFIGURACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Resumo:" -ForegroundColor Yellow
Write-Host "  Chat ID: $chatId" -ForegroundColor White
Write-Host "  Grupo ID: $grupoId" -ForegroundColor White
Write-Host ""
Write-Host "TESTE FINAL:" -ForegroundColor Yellow
Write-Host "  Envie uma mensagem no Telegram!" -ForegroundColor White
Write-Host "  Depois execute: .\verificar_mensagens_banco.ps1" -ForegroundColor White
Write-Host ""
