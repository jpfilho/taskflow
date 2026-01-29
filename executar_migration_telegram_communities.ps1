# ============================================
# EXECUTAR MIGRATION TELEGRAM_COMMUNITIES
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "ATUALIZANDO TELEGRAM_COMMUNITIES" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Copiar migration
Write-Host "Copiando migration..." -ForegroundColor Yellow
scp supabase/migrations/20260125_atualizar_telegram_communities.sql "${SERVER}:/tmp/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar migration!" -ForegroundColor Red
    exit 1
}

# Copiar script de execução
Write-Host "Copiando script de execução..." -ForegroundColor Yellow
scp executar_migration_telegram_communities.sh "${SERVER}:/root/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar script!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executando migration..." -ForegroundColor Yellow
ssh $SERVER 'chmod +x /root/executar_migration_telegram_communities.sh; bash /root/executar_migration_telegram_communities.sh'

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Migration executada com sucesso!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Erro ao executar migration!" -ForegroundColor Red
    exit 1
}
