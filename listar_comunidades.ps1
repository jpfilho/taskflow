# ============================================
# LISTAR COMUNIDADES DISPONÍVEIS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "LISTAR COMUNIDADES" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp listar_comunidades.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando listagem..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/listar_comunidades.sh && /root/listar_comunidades.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
