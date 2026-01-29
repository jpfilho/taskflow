# Script para verificar se os dados do projeto estao no Postgres
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verificar Dados Postgres" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Listar databases
Write-Host "[1/4] Listando databases..." -ForegroundColor Yellow
$databases = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -c '\l' 2>&1"
Write-Host $databases -ForegroundColor Gray

# 2. Verificar tabelas no database postgres
Write-Host ""
Write-Host "[2/4] Verificando tabelas no database postgres..." -ForegroundColor Yellow
$tables = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -d postgres -c '\dt' 2>&1"
Write-Host $tables -ForegroundColor Gray

# 3. Verificar tabelas do Supabase (auth, storage, etc)
Write-Host ""
Write-Host "[3/4] Verificando tabelas do Supabase..." -ForegroundColor Yellow
$supabaseTables = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT schemaname, tablename FROM pg_tables WHERE schemaname IN ('auth', 'storage', 'public') ORDER BY schemaname, tablename LIMIT 20;\" 2>&1"
Write-Host $supabaseTables -ForegroundColor Gray

# 4. Verificar tamanho do database
Write-Host ""
Write-Host "[4/4] Verificando tamanho do database..." -ForegroundColor Yellow
$dbSize = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT pg_size_pretty(pg_database_size('postgres')) as tamanho;\" 2>&1"
Write-Host $dbSize -ForegroundColor Gray

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Interpretacao" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Se nao aparecer tabelas:" -ForegroundColor Yellow
Write-Host "- Os dados podem ter sido perdidos (improvável - volumes sao persistentes)" -ForegroundColor White
Write-Host "- O database pode estar em outro schema" -ForegroundColor White
Write-Host "- O Supabase pode precisar ser reinicializado" -ForegroundColor White
Write-Host ""
Write-Host "Se aparecer tabelas:" -ForegroundColor Yellow
Write-Host "- Os dados estao seguros!" -ForegroundColor Green
Write-Host "- O problema pode ser apenas com o Supabase Studio (interface web)" -ForegroundColor White
Write-Host ""
