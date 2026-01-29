# ============================================
# ATUALIZAR CHAT ID - FORÇA BRUTA
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ATUALIZAR CHAT ID" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp atualizar_chat_id_forca.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando atualizacao..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/atualizar_chat_id_forca.sh && /root/atualizar_chat_id_forca.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "ATUALIZACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
