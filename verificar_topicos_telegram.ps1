# Script para verificar tópicos do Telegram e seus Chat IDs

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR TOPICOS TELEGRAM" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$query = @"
SELECT 
    ttt.task_id,
    ttt.telegram_chat_id as topic_chat_id,
    ttt.telegram_topic_id,
    ttt.topic_name,
    tc.telegram_chat_id as community_chat_id,
    c.divisao_nome,
    c.segmento_nome,
    CASE 
        WHEN ttt.telegram_chat_id = tc.telegram_chat_id THEN 'OK'
        ELSE 'DESATUALIZADO'
    END as status
FROM telegram_task_topics ttt
JOIN comunidades c ON c.id = ttt.community_id
LEFT JOIN telegram_communities tc ON tc.community_id = ttt.community_id
ORDER BY c.divisao_nome, c.segmento_nome, ttt.topic_name;
"@

Write-Host "Executando query..." -ForegroundColor Yellow
Write-Host ""

$sshCommand = "docker exec -i supabase-db psql -U postgres -d postgres -c `"$query`""

try {
    ssh $SERVER $sshCommand
} catch {
    Write-Host "Erro ao executar query: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tente executar manualmente no Supabase Studio:" -ForegroundColor Yellow
    Write-Host "1. Acesse http://localhost:54323" -ForegroundColor Cyan
    Write-Host "2. Va para SQL Editor" -ForegroundColor Cyan
    Write-Host "3. Cole a query acima" -ForegroundColor Cyan
}
