# ============================================
# ATUALIZAR SERVIDOR E TESTAR
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_DIR = "/root/telegram-webhook"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ATUALIZAR SERVIDOR E TESTAR" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando servidor atualizado..." -ForegroundColor Yellow
scp telegram-webhook-server.js "${SERVER}:${REMOTE_DIR}/"

Write-Host ""
Write-Host "2. Reiniciando servico..." -ForegroundColor Yellow
ssh $SERVER "systemctl restart telegram-webhook"
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "3. Verificando status..." -ForegroundColor Yellow
ssh $SERVER "systemctl status telegram-webhook --no-pager | head -10"

Write-Host ""
Write-Host "4. Testando endpoint com JSON valido..." -ForegroundColor Yellow
ssh $SERVER 'curl -X POST http://127.0.0.1:3001/send-message -H "Content-Type: application/json" -d "{\"mensagem_id\":\"test-123\",\"thread_type\":\"TASK\",\"thread_id\":\"test-uuid\"}" 2>&1'

Write-Host ""
Write-Host "5. Verificando logs..." -ForegroundColor Yellow
ssh $SERVER "journalctl -u telegram-webhook -n 15 --no-pager | grep -E '(send-message|Recebida|Enviando|ERRO|Erro)'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "TESTE CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
