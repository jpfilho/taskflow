# ============================================
# CORRIGIR NGINX PARA /send-message
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR NGINX PARA /send-message" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp corrigir_nginx_send_message_simples.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando correção..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/corrigir_nginx_send_message_simples.sh && /root/corrigir_nginx_send_message_simples.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CORREÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
