# ============================================
# CORRIGIR UNIQUE DE telegram_chat_id
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR CONSTRAINT UNIQUE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Removendo constraint que impede múltiplas comunidades de usar o mesmo supergrupo..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp corrigir_unique_telegram_chat_id.sh "${SERVER}:/tmp/corrigir_unique.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erro ao copiar arquivo. Tentando método alternativo..." -ForegroundColor Red
    # Método alternativo: executar SQL diretamente
    ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c \"ALTER TABLE telegram_communities DROP CONSTRAINT IF EXISTS telegram_communities_telegram_chat_id_key;\""
    ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c \"CREATE INDEX IF NOT EXISTS idx_telegram_communities_chat_id ON telegram_communities(telegram_chat_id);\""
} else {
    Write-Host ""
    Write-Host "Executando correção..." -ForegroundColor Yellow
    ssh $SERVER "chmod +x /tmp/corrigir_unique.sh && /tmp/corrigir_unique.sh"
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CORREÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
