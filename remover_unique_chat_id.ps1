# ============================================
# REMOVER CONSTRAINT UNIQUE
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "REMOVER CONSTRAINT UNIQUE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Copiando script..." -ForegroundColor Yellow
scp remover_unique_chat_id.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/remover_unique_chat_id.sh && /root/remover_unique_chat_id.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CONCLUÍDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
