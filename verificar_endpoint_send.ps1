# ============================================
# VERIFICAR ENDPOINT /send-message
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR ENDPOINT /send-message" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando se endpoint existe no Nginx..." -ForegroundColor Yellow
ssh $SERVER "grep -A 5 'location /send-message' /etc/nginx/sites-available/supabase-ssl || echo 'Endpoint NAO encontrado no Nginx!'"

Write-Host ""
Write-Host "2. Testando endpoint diretamente no servidor..." -ForegroundColor Yellow
ssh $SERVER "curl -X POST http://127.0.0.1:3001/send-message -H 'Content-Type: application/json' -d '{\"mensagem_id\":\"test\",\"thread_type\":\"TASK\",\"thread_id\":\"test\"}' 2>&1 | head -20"

Write-Host ""
Write-Host "3. Verificando logs do servidor..." -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 30 --no-pager | grep -E '(send-message|Enviando mensagem|ERRO|Erro)'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
