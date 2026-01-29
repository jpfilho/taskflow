# Script para verificar o fluxo completo de uma mensagem

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR FLUXO DE MENSAGEM" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$grupoId = Read-Host "Digite o grupo_chat.id (grupoId) da mensagem que foi enviada"

if ([string]::IsNullOrWhiteSpace($grupoId)) {
    Write-Host "Grupo ID nao fornecido!" -ForegroundColor Red
    exit 1
}

$query = @"
-- Verificar o fluxo completo de uma mensagem
-- 1. Grupo de chat
SELECT 
    gc.id as grupo_chat_id,
    gc.tarefa_id,
    gc.tarefa_nome,
    gc.comunidade_id,
    c.regional_id,
    c.regional_nome,
    c.divisao_id,
    c.divisao_nome,
    c.segmento_id,
    c.segmento_nome
FROM grupos_chat gc
JOIN comunidades c ON c.id = gc.comunidade_id
WHERE gc.id = '$grupoId';

-- 2. Tarefa associada
SELECT 
    t.id as tarefa_id,
    t.tarefa,
    t.regional_id as tarefa_regional_id,
    t.divisao_id as tarefa_divisao_id,
    t.segmento_id as tarefa_segmento_id,
    r.regional as tarefa_regional_nome,
    d.divisao as tarefa_divisao_nome,
    s.segmento as tarefa_segmento_nome
FROM tasks t
LEFT JOIN regionais r ON r.id = t.regional_id
LEFT JOIN divisoes d ON d.id = t.divisao_id
LEFT JOIN segmentos s ON s.id = t.segmento_id
WHERE t.id = (SELECT tarefa_id FROM grupos_chat WHERE id = '$grupoId');

-- 3. Comunidade e Telegram Chat ID
SELECT 
    c.id as comunidade_id,
    c.regional_id,
    c.regional_nome,
    c.divisao_id,
    c.divisao_nome,
    c.segmento_id,
    c.segmento_nome,
    tc.telegram_chat_id,
    CASE 
        WHEN tc.telegram_chat_id IS NULL THEN 'SEM CHAT ID CONFIGURADO'
        ELSE 'OK'
    END as status
FROM grupos_chat gc
JOIN comunidades c ON c.id = gc.comunidade_id
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
WHERE gc.id = '$grupoId';

-- 4. Tópico existente (se houver)
SELECT 
    ttt.id,
    ttt.task_id,
    ttt.telegram_chat_id as topico_chat_id,
    ttt.telegram_topic_id,
    ttt.topic_name,
    tc.telegram_chat_id as comunidade_chat_id,
    CASE 
        WHEN ttt.telegram_chat_id = tc.telegram_chat_id THEN 'OK - Chat IDs coincidem'
        WHEN tc.telegram_chat_id IS NULL THEN 'ERRO - Comunidade sem Chat ID'
        ELSE 'ERRO - Chat IDs diferentes!'
    END as status
FROM grupos_chat gc
JOIN tasks t ON t.id = gc.tarefa_id
LEFT JOIN telegram_task_topics ttt ON ttt.task_id = t.id
LEFT JOIN comunidades c ON c.id = gc.comunidade_id
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
WHERE gc.id = '$grupoId';
"@

Write-Host "Verificando fluxo para grupo_chat.id: $grupoId" -ForegroundColor Yellow
Write-Host ""

$sshCommand = "docker exec -i supabase-db psql -U postgres -d postgres << 'EOF'
$query
EOF"

try {
    ssh $SERVER $sshCommand
} catch {
    Write-Host "Erro ao executar query: $_" -ForegroundColor Red
}
