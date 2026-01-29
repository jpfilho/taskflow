# ============================================
# VERIFICAR SE FLUTTER ESTÁ CHAMANDO O ENDPOINT
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR CHAMADAS DO FLUTTER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp verificar_chamadas_flutter.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando verificação..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/verificar_chamadas_flutter.sh && /root/verificar_chamadas_flutter.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Agora envie uma mensagem do Flutter e veja se aparece nos logs acima." -ForegroundColor Yellow
Write-Host ""
