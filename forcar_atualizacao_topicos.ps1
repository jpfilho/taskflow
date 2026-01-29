# Script para forcar atualizacao de todos os topicos (deletar e recriar na proxima mensagem)

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "FORCAR ATUALIZACAO DE TOPICOS" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Este script vai DELETAR todos os topicos existentes" -ForegroundColor Yellow
Write-Host "Na proxima mensagem enviada, o sistema vai criar novos topicos no grupo correto" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Deseja continuar? (S/N)"

if ($confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Operacao cancelada." -ForegroundColor Yellow
    exit 0
}

$query = @"
-- Deletar TODOS os tópicos (serão recriados na próxima mensagem com Chat ID correto)
DELETE FROM telegram_task_topics;

-- Mostrar resultado
SELECT 'Todos os topicos foram deletados. Novos topicos serao criados na proxima mensagem.' as resultado;
"@

Write-Host "Executando..." -ForegroundColor Yellow
Write-Host ""

$sshCommand = "docker exec -i supabase-db psql -U postgres -d postgres -c `"$query`""

try {
    ssh $SERVER $sshCommand
    
    Write-Host ""
    Write-Host "Topicos deletados com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Na proxima mensagem enviada em cada tarefa, o sistema vai:" -ForegroundColor Cyan
    Write-Host "  1. Buscar o Chat ID atualizado da comunidade" -ForegroundColor White
    Write-Host "  2. Criar um novo topico no grupo correto" -ForegroundColor White
    Write-Host "  3. Salvar o mapeamento correto no banco" -ForegroundColor White
} catch {
    Write-Host ""
    Write-Host "Erro ao executar: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tente executar manualmente no Supabase Studio:" -ForegroundColor Yellow
    Write-Host "1. Acesse http://localhost:54323" -ForegroundColor Cyan
    Write-Host "2. Va para SQL Editor" -ForegroundColor Cyan
    Write-Host "3. Execute: DELETE FROM telegram_task_topics;" -ForegroundColor Cyan
}
