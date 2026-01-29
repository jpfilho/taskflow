# ============================================
# CRIAR SUBSCRIPTIONS AUTOMATICAMENTE
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CRIAR SUBSCRIPTIONS AUTOMATICAMENTE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Chat ID do grupo TaskFlow
$chatId = "-5127731041"

Write-Host "Chat ID Telegram: $chatId" -ForegroundColor White
Write-Host "Modo: group_plain (todas as tarefas no mesmo grupo)" -ForegroundColor White
Write-Host ""

Write-Host "ATENCAO:" -ForegroundColor Yellow
Write-Host "  Este script vai criar uma subscription para CADA tarefa" -ForegroundColor White
Write-Host "  Todas as mensagens irao para o mesmo grupo do Telegram" -ForegroundColor White
Write-Host ""

$confirma = Read-Host "Continuar? (S/N)"

if ($confirma -ne "S" -and $confirma -ne "s") {
    Write-Host ""
    Write-Host "Cancelado." -ForegroundColor Gray
    exit
}

Write-Host ""
Write-Host "Copiando script..." -ForegroundColor Yellow
scp criar_subscriptions_auto.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/criar_subscriptions_auto.sh"

Write-Host ""
Write-Host "Executando criacao automatica..." -ForegroundColor Yellow
ssh $SERVER "/root/criar_subscriptions_auto.sh $chatId"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "AGORA TESTE:" -ForegroundColor Yellow
Write-Host ""
Write-Host "TESTE 1 - Telegram para App:" -ForegroundColor Cyan
Write-Host "  1. Envie mensagem no grupo Telegram 'TaskFlow'" -ForegroundColor White
Write-Host "  2. Execute: .\verificar_mensagens_banco.ps1" -ForegroundColor Gray
Write-Host "  3. Abra o app Flutter e veja se apareceu" -ForegroundColor Gray
Write-Host ""
Write-Host "TESTE 2 - App para Telegram:" -ForegroundColor Cyan
Write-Host "  1. Abra qualquer chat no app Flutter" -ForegroundColor White
Write-Host "  2. Envie uma mensagem" -ForegroundColor Gray
Write-Host "  3. Verifique se aparece no Telegram" -ForegroundColor Gray
Write-Host ""
Write-Host "OBSERVACAO:" -ForegroundColor Yellow
Write-Host "  Todas as tarefas estao no mesmo grupo do Telegram" -ForegroundColor White
Write-Host "  Para organizar melhor, use Supergrupo + Topicos" -ForegroundColor White
Write-Host "  (Ver arquivo: TELEGRAM_ESTRUTURA.md)" -ForegroundColor White
Write-Host ""
