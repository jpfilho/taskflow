# Script para corrigir topicos desatualizados (atualizar Chat ID dos topicos)

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR TOPICOS DESATUALIZADOS" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Este script atualiza os Chat IDs dos topicos para usar o Chat ID atualizado da comunidade." -ForegroundColor Yellow
Write-Host ""

$query = @"
-- Atualizar topicos com Chat ID desatualizado
UPDATE telegram_task_topics ttt
SET 
    telegram_chat_id = tc.telegram_chat_id,
    updated_at = NOW()
FROM telegram_communities tc
WHERE ttt.community_id = tc.community_id
  AND ttt.telegram_chat_id != tc.telegram_chat_id
  AND tc.telegram_chat_id IS NOT NULL;

-- Mostrar quantos foram atualizados
SELECT 
    COUNT(*) as topicos_atualizados
FROM telegram_task_topics ttt
JOIN telegram_communities tc ON tc.community_id = ttt.community_id
WHERE ttt.telegram_chat_id = tc.telegram_chat_id;
"@

Write-Host "Executando correcao..." -ForegroundColor Yellow
Write-Host ""

$sshCommand = "docker exec -i supabase-db psql -U postgres -d postgres -c `"$query`""

try {
    ssh $SERVER $sshCommand
    
    Write-Host ""
    Write-Host "Correcao executada!" -ForegroundColor Green
    Write-Host ""
    Write-Host "NOTA: Os topicos foram atualizados no banco, mas os topicos antigos no Telegram ainda existem." -ForegroundColor Yellow
    Write-Host "O sistema criara novos topicos automaticamente na proxima mensagem." -ForegroundColor Yellow
} catch {
    Write-Host "Erro ao executar correcao: $_" -ForegroundColor Red
}
