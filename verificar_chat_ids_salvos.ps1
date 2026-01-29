# Script para verificar se os Chat IDs foram salvos no Supabase
# Conecta ao Supabase e lista os Chat IDs salvos para uma divisão

param(
    [Parameter(Mandatory=$false)]
    [string]$DivisaoId = ""
)

$hostname = "localhost"
$username = "postgres"
$database = "postgres"

Write-Host "🔍 Verificando Chat IDs salvos no Supabase..." -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrEmpty($DivisaoId)) {
    Write-Host "Listando TODOS os Chat IDs salvos:" -ForegroundColor Yellow
    Write-Host ""
    
    $query = @"
SELECT 
    tc.community_id,
    tc.telegram_chat_id,
    c.divisao_nome,
    c.segmento_nome,
    c.divisao_id,
    c.segmento_id
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.community_id
ORDER BY c.divisao_nome, c.segmento_nome;
"@
} else {
    Write-Host "Listando Chat IDs para divisão ID: $DivisaoId" -ForegroundColor Yellow
    Write-Host ""
    
    $query = @"
SELECT 
    tc.community_id,
    tc.telegram_chat_id,
    c.divisao_nome,
    c.segmento_nome,
    c.divisao_id,
    c.segmento_id
FROM telegram_communities tc
JOIN comunidades c ON c.id = tc.community_id
WHERE c.divisao_id = '$DivisaoId'
ORDER BY c.segmento_nome;
"@
}

$sshCommand = "docker exec supabase-db psql -U postgres -d postgres -c `"$query`""

try {
    ssh $hostname $sshCommand
} catch {
    Write-Host "❌ Erro ao executar query: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tente executar manualmente no Supabase Studio:" -ForegroundColor Yellow
    Write-Host "  1. Acesse http://localhost:54323" -ForegroundColor Cyan
    Write-Host "  2. Vá para SQL Editor" -ForegroundColor Cyan
    Write-Host "  3. Execute a query acima" -ForegroundColor Cyan
}
