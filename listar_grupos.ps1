# ============================================
# LISTAR GRUPOS DO SISTEMA
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "GRUPOS NO SISTEMA" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Buscando grupos/tarefas..." -ForegroundColor Yellow
Write-Host ""

# Tentar diferentes tabelas possíveis
$sql = @"
-- Tentar grupos_chat
SELECT 'grupos_chat' as tabela, id, nome, created_at 
FROM grupos_chat 
ORDER BY created_at DESC 
LIMIT 10;
"@

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sql`""

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
