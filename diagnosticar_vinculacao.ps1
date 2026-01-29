# ============================================
# DIAGNOSTICAR VINCULACAO DO TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICO DE VINCULACAO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se a tabela existe
Write-Host "1. Verificando tabela telegram_identities..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c '\d telegram_identities'"

Write-Host ""
Write-Host "2. Verificando registros na tabela..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT * FROM telegram_identities;'"

Write-Host ""
Write-Host "3. Usuarios no sistema..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT id, email, raw_user_meta_data FROM auth.users LIMIT 5;'"

Write-Host ""
Write-Host "4. Ultimos logs do webhook..." -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 30 --no-pager | grep -E '(vinculado|identidade|JOSE|7807721517)'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
