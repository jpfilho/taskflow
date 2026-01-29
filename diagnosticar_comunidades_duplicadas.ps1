# Script para diagnosticar comunidades duplicadas e verificar se regional_id foi adicionado

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICO DE COMUNIDADES" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$query = @"
-- 1. Verificar se a coluna regional_id existe
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'comunidades' 
AND column_name = 'regional_id';

-- 2. Verificar comunidades duplicadas (mesma divisao + segmento, mas regionais diferentes)
SELECT 
    c1.id as comunidade1_id,
    c1.regional_id as regional1_id,
    c1.divisao_id,
    c1.segmento_id,
    c2.id as comunidade2_id,
    c2.regional_id as regional2_id,
    COUNT(*) as duplicatas
FROM comunidades c1
JOIN comunidades c2 ON 
    c1.divisao_id = c2.divisao_id 
    AND c1.segmento_id = c2.segmento_id
    AND c1.id != c2.id
GROUP BY c1.id, c1.regional_id, c1.divisao_id, c1.segmento_id, c2.id, c2.regional_id
HAVING COUNT(*) > 0;

-- 3. Listar todas as comunidades com seus Chat IDs
SELECT 
    c.id as comunidade_id,
    c.regional_id,
    c.regional_nome,
    c.divisao_id,
    c.divisao_nome,
    c.segmento_id,
    c.segmento_nome,
    tc.telegram_chat_id,
    COUNT(gc.id) as total_grupos_chat
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
LEFT JOIN grupos_chat gc ON gc.comunidade_id = c.id
GROUP BY c.id, c.regional_id, c.regional_nome, c.divisao_id, c.divisao_nome, c.segmento_id, c.segmento_nome, tc.telegram_chat_id
ORDER BY c.divisao_nome, c.segmento_nome, c.regional_nome;

-- 4. Verificar grupos_chat vinculados a comunidades
SELECT 
    gc.id as grupo_chat_id,
    gc.tarefa_id,
    gc.tarefa_nome,
    gc.comunidade_id,
    c.regional_nome,
    c.divisao_nome,
    c.segmento_nome,
    tc.telegram_chat_id,
    t.regional_id as tarefa_regional_id,
    t.divisao_id as tarefa_divisao_id,
    t.segmento_id as tarefa_segmento_id
FROM grupos_chat gc
JOIN comunidades c ON c.id = gc.comunidade_id
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
LEFT JOIN tasks t ON t.id = gc.tarefa_id
WHERE c.divisao_nome LIKE '%NEPTRFMT%' OR c.segmento_nome LIKE '%Linhas de Transmissão%'
ORDER BY gc.tarefa_nome;
"@

Write-Host "Executando diagnosticos..." -ForegroundColor Yellow
Write-Host ""

$sshCommand = "docker exec -i supabase-db psql -U postgres -d postgres << 'EOF'
$query
EOF"

try {
    ssh $SERVER $sshCommand
} catch {
    Write-Host "Erro ao executar query: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "ALTERNATIVA: Execute manualmente no Supabase Studio:" -ForegroundColor Yellow
    Write-Host "1. Acesse http://localhost:54323" -ForegroundColor Cyan
    Write-Host "2. Va para SQL Editor" -ForegroundColor Cyan
    Write-Host "3. Cole a query acima" -ForegroundColor Cyan
}
