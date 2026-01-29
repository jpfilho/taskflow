# ============================================
# MONITORAR CHAMADAS DO FLUTTER EM TEMPO REAL
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MONITORAR CHAMADAS DO FLUTTER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Envie uma mensagem do Flutter agora!" -ForegroundColor Yellow
Write-Host "Pressione Ctrl+C para parar." -ForegroundColor Yellow
Write-Host ""

ssh $SERVER "journalctl -u telegram-webhook -f --no-pager" | Select-String -Pattern "(send-message|Recebida requisição|Enviando mensagem|Mensagem enviada|Erro ao enviar)"
