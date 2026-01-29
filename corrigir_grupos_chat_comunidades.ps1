# Script para corrigir grupos_chat vinculados a comunidades erradas
# Verifica se grupos_chat estao vinculados a comunidades que nao correspondem a regional+divisao+segmento da tarefa

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR GRUPOS_CHAT E COMUNIDADES" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$query = @"
-- 1. Verificar grupos_chat com comunidades incorretas
SELECT 
    gc.id as grupo_chat_id,
    gc.tarefa_id,
    gc.tarefa_nome,
    gc.comunidade_id as comunidade_atual_id,
    c_atual.regional_id as comunidade_regional_id,
    c_atual.divisao_id as comunidade_divisao_id,
    c_atual.segmento_id as comunidade_segmento_id,
    t.regional_id as tarefa_regional_id,
    t.divisao_id as tarefa_divisao_id,
    t.segmento_id as tarefa_segmento_id,
    CASE 
        WHEN c_atual.regional_id IS NULL THEN 'COMUNIDADE SEM REGIONAL_ID'
        WHEN c_atual.regional_id != t.regional_id THEN 'REGIONAL DIFERENTE'
        WHEN c_atual.divisao_id != t.divisao_id THEN 'DIVISAO DIFERENTE'
        WHEN c_atual.segmento_id != t.segmento_id THEN 'SEGMENTO DIFERENTE'
        ELSE 'OK'
    END as status
FROM grupos_chat gc
JOIN tasks t ON t.id = gc.tarefa_id
JOIN comunidades c_atual ON c_atual.id = gc.comunidade_id
WHERE t.regional_id IS NOT NULL 
    AND t.divisao_id IS NOT NULL 
    AND t.segmento_id IS NOT NULL
    AND (
        c_atual.regional_id IS NULL 
        OR c_atual.regional_id != t.regional_id 
        OR c_atual.divisao_id != t.divisao_id 
        OR c_atual.segmento_id != t.segmento_id
    )
ORDER BY gc.tarefa_nome;

-- 2. Buscar comunidades corretas para essas tarefas
SELECT 
    gc.id as grupo_chat_id,
    gc.tarefa_id,
    c_correta.id as comunidade_correta_id,
    c_correta.regional_nome,
    c_correta.divisao_nome,
    c_correta.segmento_nome,
    tc.telegram_chat_id
FROM grupos_chat gc
JOIN tasks t ON t.id = gc.tarefa_id
LEFT JOIN comunidades c_correta ON 
    c_correta.regional_id = t.regional_id
    AND c_correta.divisao_id = t.divisao_id
    AND c_correta.segmento_id = t.segmento_id
LEFT JOIN telegram_communities tc ON tc.community_id = c_correta.id
WHERE t.regional_id IS NOT NULL 
    AND t.divisao_id IS NOT NULL 
    AND t.segmento_id IS NOT NULL
    AND gc.comunidade_id != c_correta.id
ORDER BY gc.tarefa_nome;
"@

Write-Host "Verificando grupos_chat com comunidades incorretas..." -ForegroundColor Yellow
Write-Host ""

$sshCommand = "docker exec -i supabase-db psql -U postgres -d postgres << 'EOF'
$query
EOF"

try {
    ssh $SERVER $sshCommand
} catch {
    Write-Host "Erro ao executar query: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "SCRIPT DE CORRECAO" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para corrigir automaticamente, execute a query abaixo no Supabase Studio:" -ForegroundColor Yellow
Write-Host ""
Write-Host "-- Corrigir grupos_chat vinculados a comunidades erradas" -ForegroundColor Gray
Write-Host "UPDATE grupos_chat gc" -ForegroundColor Gray
Write-Host "SET comunidade_id = c_correta.id" -ForegroundColor Gray
Write-Host "FROM tasks t" -ForegroundColor Gray
Write-Host "JOIN comunidades c_correta ON" -ForegroundColor Gray
Write-Host "    c_correta.regional_id = t.regional_id" -ForegroundColor Gray
Write-Host "    AND c_correta.divisao_id = t.divisao_id" -ForegroundColor Gray
Write-Host "    AND c_correta.segmento_id = t.segmento_id" -ForegroundColor Gray
Write-Host "WHERE gc.tarefa_id = t.id" -ForegroundColor Gray
Write-Host "    AND t.regional_id IS NOT NULL" -ForegroundColor Gray
Write-Host "    AND t.divisao_id IS NOT NULL" -ForegroundColor Gray
Write-Host "    AND t.segmento_id IS NOT NULL" -ForegroundColor Gray
Write-Host "    AND gc.comunidade_id != c_correta.id;" -ForegroundColor Gray
Write-Host ""
