# Script para executar a correcao de comunidades com regional_id NULL

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR COMUNIDADES COM REGIONAL_ID NULL" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$migrationFile = "supabase\migrations\20260125_corrigir_comunidades_null_regional.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "Arquivo de migracao nao encontrado: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Copiando arquivo de migracao..." -ForegroundColor Yellow
scp $migrationFile "${SERVER}:/tmp/corrigir_comunidades_null.sql"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar arquivo!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando migracao..." -ForegroundColor Yellow
ssh $SERVER 'docker exec -i supabase-db psql -U postgres -d postgres < /tmp/corrigir_comunidades_null.sql'

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Migracao executada com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Agora todas as comunidades tem regional_id e os grupos_chat estao corrigidos!" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Erro ao executar migracao!" -ForegroundColor Red
}
