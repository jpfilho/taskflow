# Script para executar a migracao que adiciona regional_id a comunidades

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "ADICIONAR REGIONAL_ID A COMUNIDADES" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$migrationFile = "supabase\migrations\20260125_adicionar_regional_comunidades.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "Arquivo de migracao nao encontrado: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Copiando arquivo de migracao..." -ForegroundColor Yellow
scp $migrationFile "${SERVER}:/tmp/adicionar_regional_comunidades.sql"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar arquivo!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando migracao..." -ForegroundColor Yellow
ssh $SERVER 'docker exec -i supabase-db psql -U postgres -d postgres < /tmp/adicionar_regional_comunidades.sql'

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Migracao executada com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Agora cada combinacao de Regional + Divisao + Segmento tera sua propria comunidade e Chat ID!" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Erro ao executar migracao!" -ForegroundColor Red
}
