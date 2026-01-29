# Script para executar a correcao de RLS da tabela telegram_communities (versao 2)

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR RLS TELEGRAM_COMMUNITIES V2" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$migrationFile = "supabase\migrations\20260125_fix_telegram_communities_rls_v2.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "Arquivo de migracao nao encontrado: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Copiando arquivo de migracao..." -ForegroundColor Yellow
scp $migrationFile "${SERVER}:/tmp/fix_rls_telegram_v2.sql"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar arquivo!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando migracao..." -ForegroundColor Yellow
ssh $SERVER 'docker exec -i supabase-db psql -U postgres -d postgres < /tmp/fix_rls_telegram_v2.sql'

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Migracao executada com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Agora tente salvar a divisao novamente no Flutter." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NOTA: Se ainda der erro, pode ser necessario fazer hot restart (R) no Flutter" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Erro ao executar migracao!" -ForegroundColor Red
}
