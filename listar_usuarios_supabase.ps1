# ============================================
# LISTAR USUARIOS DO SUPABASE
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "USUARIOS NO SUPABASE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Buscando usuarios..." -ForegroundColor Yellow
Write-Host ""

$sql = "SELECT id, email, raw_user_meta_data->>'full_name' as nome, created_at FROM auth.users ORDER BY created_at DESC LIMIT 20;"

ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$sql`""

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para vincular um usuario, copie o UUID e execute:" -ForegroundColor Yellow
Write-Host "  .\vincular_usuario_telegram.ps1" -ForegroundColor White
Write-Host ""
