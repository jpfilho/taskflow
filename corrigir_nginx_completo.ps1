# ============================================
# CORRIGIR NGINX COMPLETO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGIR NGINX" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando estrutura atual do Nginx..." -ForegroundColor Yellow
ssh $SERVER "cat /etc/nginx/sites-available/supabase-ssl | head -50"

Write-Host ""
Write-Host "2. Removendo configuracoes incorretas..." -ForegroundColor Yellow
ssh $SERVER "sed -i '/location \/send-message/,/^    }/d' /etc/nginx/sites-available/supabase-ssl"

Write-Host ""
Write-Host "3. Copiando script de correcao..." -ForegroundColor Yellow
scp corrigir_nginx_send_message.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/corrigir_nginx_send_message.sh"

Write-Host ""
Write-Host "4. Executando correcao..." -ForegroundColor Yellow
ssh $SERVER "/root/corrigir_nginx_send_message.sh"

Write-Host ""
Write-Host "5. Verificando configuracao final..." -ForegroundColor Yellow
ssh $SERVER "grep -A 8 'location /send-message' /etc/nginx/sites-available/supabase-ssl"

Write-Host ""
Write-Host "6. Testando endpoint..." -ForegroundColor Yellow
$testUrl = "https://api.taskflowv3.com.br/send-message"
$testBody = @{
    mensagem_id = "test-123"
    thread_type = "TASK"
    thread_id = "test-uuid"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $testUrl -Method Post -Body $testBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "   Endpoint funcionando!" -ForegroundColor Green
    Write-Host "   Resposta: $($response | ConvertTo-Json)" -ForegroundColor Gray
} catch {
    Write-Host "   ERRO: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "   Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CORRECAO CONCLUIDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
