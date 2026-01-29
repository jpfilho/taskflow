# ============================================
# CORRIGIR FOREIGN KEY E REVINCULAR
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR FOREIGN KEY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando script SQL..." -ForegroundColor Yellow
scp corrigir_foreign_key.sql "${SERVER}:/root/"

Write-Host ""
Write-Host "2. Executando correcao..." -ForegroundColor Yellow
ssh $SERVER "docker exec -i supabase-db psql -U postgres -d postgres < /root/corrigir_foreign_key.sql"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CORRECAO CONCLUIDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora envie uma mensagem no Telegram:" -ForegroundColor Yellow
Write-Host "  'Teste de vinculacao corrigida!'" -ForegroundColor White
Write-Host ""
