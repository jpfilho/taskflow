# Script para executar a correcao de RLS da tabela telegram_communities

$hostname = "localhost"
$username = "postgres"
$database = "postgres"

Write-Host "Corrigindo politicas RLS da tabela telegram_communities..." -ForegroundColor Cyan
Write-Host ""

$migrationFile = "supabase\migrations\20260125_fix_telegram_communities_rls.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "Arquivo de migracao nao encontrado: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Lendo arquivo de migracao..." -ForegroundColor Yellow
$sqlContent = Get-Content $migrationFile -Raw -Encoding UTF8

Write-Host "Executando migracao no Supabase..." -ForegroundColor Yellow
Write-Host ""

# Executar via Docker
$sqlContent | docker exec -i supabase-db psql -U postgres -d postgres

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Migracao executada com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Agora tente salvar a divisao novamente no Flutter." -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Erro ao executar migracao!" -ForegroundColor Red
    Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Red
}
