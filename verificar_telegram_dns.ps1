# ============================================
# VERIFICAR DNS E TELEGRAM
# ============================================

$SERVER = "root@212.85.0.249"
$DOMINIO = "api.taskflowv3.com.br"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICANDO DNS E TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando DNS do dominio correto..." -ForegroundColor Yellow
Write-Host "   Dominio: $DOMINIO" -ForegroundColor Gray
nslookup $DOMINIO 8.8.8.8

Write-Host ""
Write-Host "2. Testando acesso HTTPS ao dominio..." -ForegroundColor Yellow
curl -I https://${DOMINIO}/ 2>&1 | Select-String -Pattern "HTTP|Server|Location" | Select-Object -First 5

Write-Host ""
Write-Host "3. Verificando certificado SSL..." -ForegroundColor Yellow
ssh $SERVER "ls -la /etc/letsencrypt/live/$DOMINIO/ 2>/dev/null || echo 'Certificado nao encontrado'"

Write-Host ""
Write-Host "4. Verificando configuracao Nginx para $DOMINIO..." -ForegroundColor Yellow
ssh $SERVER "cat /etc/nginx/sites-enabled/* | grep -A 5 'server_name.*$DOMINIO'"

Write-Host ""
Write-Host "5. Verificando variaveis de ambiente do Telegram..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-kong env | grep TELEGRAM"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "PROXIMO PASSO:" -ForegroundColor Yellow
Write-Host "   Configurar webhook: https://$DOMINIO/functions/v1/telegram-webhook" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
