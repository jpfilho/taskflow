# Script para verificar qual Chat ID esta sendo usado para uma tarefa especifica

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId
)

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR CHAT ID DA TAREFA" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Task ID: $TaskId" -ForegroundColor Yellow
Write-Host ""

$query = @"
-- Verificar grupo_chat e comunidade da tarefa
SELECT 
    gc.id as grupo_chat_id,
    gc.tarefa_id,
    gc.tarefa_nome,
    gc.comunidade_id,
    c.divisao_nome,
    c.segmento_nome,
    tc.telegram_chat_id as chat_id_atualizado,
    ttt.telegram_chat_id as chat_id_topic,
    ttt.telegram_topic_id,
    ttt.topic_name,
    CASE 
        WHEN tc.telegram_chat_id IS NULL THEN 'SEM CHAT ID'
        WHEN ttt.telegram_chat_id IS NULL THEN 'SEM TOPICO'
        WHEN ttt.telegram_chat_id = tc.telegram_chat_id THEN 'OK'
        ELSE 'DESATUALIZADO'
    END as status
FROM grupos_chat gc
JOIN comunidades c ON c.id = gc.comunidade_id
LEFT JOIN telegram_communities tc ON tc.community_id = gc.comunidade_id
LEFT JOIN telegram_task_topics ttt ON ttt.task_id = gc.tarefa_id
WHERE gc.tarefa_id = '$TaskId';
"@

Write-Host "Executando query..." -ForegroundColor Yellow
Write-Host ""

$sshCommand = "docker exec -i supabase-db psql -U postgres -d postgres -c `"$query`""

try {
    ssh $SERVER $sshCommand
} catch {
    Write-Host "Erro ao executar query: $_" -ForegroundColor Red
}
