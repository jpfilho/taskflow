# ============================================
# ATUALIZAR WEBHOOK COM CORRECAO
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_DIR = "/root/telegram-webhook"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ATUALIZAR WEBHOOK" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Copiando arquivo corrigido..." -ForegroundColor Yellow
scp telegram-webhook-server.js "${SERVER}:${REMOTE_DIR}/"

Write-Host ""
Write-Host "2. Reiniciando servico..." -ForegroundColor Yellow
ssh $SERVER "systemctl restart telegram-webhook"

Write-Host ""
Write-Host "Aguardando 3 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "3. Verificando status..." -ForegroundColor Yellow
ssh $SERVER "systemctl status telegram-webhook --no-pager | head -15"

Write-Host ""
Write-Host "4. Verificando vinculacao no banco..." -ForegroundColor Yellow
ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT ti.telegram_user_id, ti.telegram_first_name, e.matricula, e.nome FROM telegram_identities ti JOIN executores e ON e.id = ti.user_id WHERE ti.telegram_user_id = 7807721517;'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "WEBHOOK ATUALIZADO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Agora envie OUTRA mensagem no Telegram!" -ForegroundColor Yellow
Write-Host "Exemplo: 'Teste de vinculacao!'" -ForegroundColor White
Write-Host ""
