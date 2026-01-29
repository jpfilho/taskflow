# ============================================
# VERIFICAR INTEGRAÇÃO FLUTTER -> NODE.JS
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR INTEGRAÇÃO FLUTTER -> NODE.JS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_integracao_node.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando verificação..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/verificar_integracao_node.sh && /root/verificar_integracao_node.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
