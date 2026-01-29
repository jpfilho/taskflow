# ============================================
# BUSCAR INFORMAÇÕES DA TAREFA
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "INFORMAÇÕES DA TAREFA" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp buscar_info_tarefa.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando busca..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/buscar_info_tarefa.sh && /root/buscar_info_tarefa.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
