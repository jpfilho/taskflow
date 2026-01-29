# Script para executar a correcao de grupos_chat e comunidades

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR GRUPOS_CHAT E COMUNIDADES" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$migrationFile = "supabase\migrations\20260125_corrigir_grupos_chat_comunidades.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "Arquivo de migracao nao encontrado: $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "IMPORTANTE: Execute primeiro a migration que adiciona regional_id!" -ForegroundColor Yellow
Write-Host "  .\executar_migration_regional_comunidades.ps1" -ForegroundColor Cyan
Write-Host ""
$confirm = Read-Host "Deseja continuar? (S/N)"

if ($confirm -ne "S" -and $confirm -ne "s") {
    Write-Host "Cancelado." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Copiando arquivo de migracao..." -ForegroundColor Yellow
scp $migrationFile "${SERVER}:/tmp/corrigir_grupos_chat.sql"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar arquivo!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando migracao..." -ForegroundColor Yellow
ssh $SERVER 'docker exec -i supabase-db psql -U postgres -d postgres < /tmp/corrigir_grupos_chat.sql'

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Migracao executada com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Agora os grupos_chat estao vinculados as comunidades corretas!" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Erro ao executar migracao!" -ForegroundColor Red
}
