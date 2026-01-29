# Script para limpar tópicos antigos que estão com Chat ID desatualizado

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "LIMPAR TOPICOS ANTIGOS COM CHAT ID DESATUALIZADO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Este script vai DELETAR tópicos que estao com Chat ID diferente do atual da comunidade" -ForegroundColor Yellow
Write-Host "Isso vai forcar a criacao de novos topicos no grupo correto na proxima mensagem" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Deseja continuar? (S/N)"

if ($confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Operacao cancelada." -ForegroundColor Yellow
    exit 0
}

$query = @"
-- Deletar tópicos que estão com Chat ID diferente do atual da comunidade
DELETE FROM telegram_task_topics ttt
WHERE EXISTS (
    SELECT 1 
    FROM telegram_communities tc
    WHERE tc.community_id = ttt.community_id
    AND tc.telegram_chat_id != ttt.telegram_chat_id
);

-- Mostrar quantos foram deletados
SELECT COUNT(*) as topicos_deletados
FROM telegram_task_topics;
"@

Write-Host "Executando limpeza..." -ForegroundColor Yellow
Write-Host ""

$sshCommand = "docker exec -i supabase-db psql -U postgres -d postgres -c `"$query`""

try {
    ssh $SERVER $sshCommand
    
    Write-Host ""
    Write-Host "Limpeza concluida!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Na proxima mensagem enviada, o sistema vai criar um novo topico no grupo correto." -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "Erro ao executar limpeza: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tente executar manualmente no Supabase Studio:" -ForegroundColor Yellow
    Write-Host "1. Acesse http://localhost:54323" -ForegroundColor Cyan
    Write-Host "2. Va para SQL Editor" -ForegroundColor Cyan
    Write-Host "3. Execute a query acima" -ForegroundColor Cyan
}
