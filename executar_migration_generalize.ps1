# ============================================
# EXECUTAR MIGRATION TELEGRAM GENERALIZADO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "EXECUTAR MIGRATION" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando arquivo de migration..." -ForegroundColor Yellow
scp supabase/migrations/20260124_telegram_generalize.sql "${SERVER}:/root/"

Write-Host ""
Write-Host "2. Copiando script de execução..." -ForegroundColor Yellow
scp executar_migration_generalize.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "3. Executando migration..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/executar_migration_generalize.sh && /root/executar_migration_generalize.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "MIGRATION CONCLUÍDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
