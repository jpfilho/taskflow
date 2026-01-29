# ============================================
# DEPLOY SERVIDOR GENERALIZADO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DEPLOY SERVIDOR GENERALIZADO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando arquivo generalizado..." -ForegroundColor Yellow
scp telegram-webhook-server-generalized.js "${SERVER}:/root/"

Write-Host ""
Write-Host "2. Copiando script de deploy..." -ForegroundColor Yellow
scp deploy_servidor_generalizado.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "3. Executando deploy..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/deploy_servidor_generalizado.sh && /root/deploy_servidor_generalizado.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUÍDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
