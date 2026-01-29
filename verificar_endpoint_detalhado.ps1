# ============================================
# VERIFICAR E CORRIGIR ENDPOINT /send-message
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR ENDPOINT /send-message" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando se endpoint existe no codigo..." -ForegroundColor Yellow
ssh $SERVER "grep -n 'app.post.*send-message' /root/telegram-webhook/telegram-webhook-server.js"

Write-Host ""
Write-Host "2. Testando endpoint diretamente no servidor (HTTP local)..." -ForegroundColor Yellow
ssh $SERVER "curl -X POST http://127.0.0.1:3001/send-message -H 'Content-Type: application/json' -d '{\"mensagem_id\":\"test\",\"thread_type\":\"TASK\",\"thread_id\":\"test\"}' 2>&1"

Write-Host ""
Write-Host "3. Verificando logs do servidor..." -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 20 --no-pager | tail -10"

Write-Host ""
Write-Host "4. Reiniciando servico..." -ForegroundColor Yellow
ssh $SERVER "systemctl restart telegram-webhook"
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "5. Testando novamente..." -ForegroundColor Yellow
ssh $SERVER "curl -X POST http://127.0.0.1:3001/send-message -H 'Content-Type: application/json' -d '{\"mensagem_id\":\"test\",\"thread_type\":\"TASK\",\"thread_id\":\"test\"}' 2>&1"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
