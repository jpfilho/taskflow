# ============================================
# CONFIGURAR NGINX E TESTAR
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CONFIGURAR NGINX /send-message" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando script de configuracao..." -ForegroundColor Yellow
scp configurar_nginx_send_message.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/configurar_nginx_send_message.sh"

Write-Host ""
Write-Host "2. Executando configuracao..." -ForegroundColor Yellow
ssh $SERVER "/root/configurar_nginx_send_message.sh"

Write-Host ""
Write-Host "3. Verificando se endpoint esta configurado..." -ForegroundColor Yellow
ssh $SERVER "grep -A 8 'location /send-message' /etc/nginx/sites-available/supabase-ssl"

Write-Host ""
Write-Host "4. Testando endpoint via HTTPS..." -ForegroundColor Yellow
$testUrl = "https://api.taskflowv3.com.br/send-message"
$testBody = @{
    mensagem_id = "test-123"
    thread_type = "TASK"
    thread_id = "test-uuid"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $testUrl -Method Post -Body $testBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "   Resposta: $($response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "   ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CONFIGURACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "AGORA NO FLUTTER:" -ForegroundColor Yellow
Write-Host "  1. Execute: flutter pub get" -ForegroundColor White
Write-Host "  2. Reinicie o app" -ForegroundColor White
Write-Host "  3. Envie uma mensagem no chat" -ForegroundColor White
Write-Host "  4. Verifique se aparece no Telegram!" -ForegroundColor White
Write-Host ""
