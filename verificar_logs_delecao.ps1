# ============================================
# VERIFICAR LOGS DE DELEÇÃO DE MENSAGEM
# ============================================

$SERVER = "root@212.85.0.249"
$MENSAGEM_ID = "6d9af518-bdcf-4cd5-91ed-03ea01baf413"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR LOGS DE DELEÇÃO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Mensagem ID: $MENSAGEM_ID" -ForegroundColor Gray
Write-Host ""

# Buscar logs relacionados à mensagem
Write-Host "Buscando logs relacionados à mensagem..." -ForegroundColor Yellow
$logs = ssh $SERVER "journalctl -u telegram-webhook -n 200 --no-pager | grep -E '$MENSAGEM_ID|deleteMessageEverywhere.*6d9af518|Deletando no Telegram.*61'"

if ($logs) {
    Write-Host "Logs encontrados:" -ForegroundColor Green
    $logs | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    Write-Host "   [ATENÇÃO] Nenhum log encontrado para esta mensagem" -ForegroundColor Yellow
    Write-Host "   Isso pode significar que a deleção não foi chamada" -ForegroundColor Yellow
}

Write-Host ""

# Buscar logs de deleção recentes
Write-Host "Últimas deleções processadas:" -ForegroundColor Yellow
$recentDeletes = ssh $SERVER "journalctl -u telegram-webhook -n 50 --no-pager | grep -E 'deleteMessageEverywhere.*Iniciando|Deleção concluída' | tail -10"
if ($recentDeletes) {
    $recentDeletes | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    Write-Host "   Nenhuma deleção recente encontrada" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "PRÓXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Se não há logs, a deleção pode não ter sido chamada" -ForegroundColor Yellow
Write-Host "2. Verifique se o endpoint /delete-message está acessível" -ForegroundColor Yellow
Write-Host "3. Tente deletar novamente e monitore os logs:" -ForegroundColor Yellow
Write-Host "   ssh $SERVER 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
