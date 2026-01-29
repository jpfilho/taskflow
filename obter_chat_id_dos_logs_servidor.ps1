# ============================================
# OBTER CHAT ID DOS LOGS DO SERVIDOR
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OBTER CHAT ID DOS LOGS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "INSTRUCAO:" -ForegroundColor Yellow
Write-Host "  1. Envie UMA MENSAGEM no grupo do Telegram AGORA" -ForegroundColor White
Write-Host "  2. Aguarde 5 segundos" -ForegroundColor White
Write-Host "  3. Pressione ENTER aqui" -ForegroundColor White
Write-Host ""

Read-Host "Pressione ENTER quando tiver enviado a mensagem"

Write-Host ""
Write-Host "Buscando nos logs do webhook..." -ForegroundColor Yellow
Write-Host ""

# Buscar Chat ID nos logs
$logs = ssh $SERVER "journalctl -u telegram-webhook -n 100 --no-pager"

Write-Host "Ultimas mensagens recebidas:" -ForegroundColor Cyan
Write-Host ""

# Extrair e mostrar chat IDs únicos
$chatIds = @{}

foreach ($line in $logs -split "`n") {
    if ($line -match '"chat":\s*\{[^}]*"id":\s*(-?\d+)') {
        $chatId = $matches[1]
        if ($line -match '"title":\s*"([^"]+)"') {
            $title = $matches[1]
            $chatIds[$chatId] = $title
        } elseif ($line -match '"first_name":\s*"([^"]+)"') {
            $firstName = $matches[1]
            $chatIds[$chatId] = "DM com $firstName"
        } else {
            $chatIds[$chatId] = "Chat"
        }
    }
}

if ($chatIds.Count -eq 0) {
    Write-Host "Nenhum chat encontrado nos logs!" -ForegroundColor Red
    Write-Host ""
    Write-Host "ALTERNATIVAS:" -ForegroundColor Yellow
    Write-Host "  1. Adicione @getidsbot ao grupo do Telegram" -ForegroundColor White
    Write-Host "  2. O bot mostrara o Chat ID automaticamente" -ForegroundColor White
    Write-Host ""
} else {
    foreach ($chatId in $chatIds.Keys) {
        Write-Host "Chat ID: $chatId" -ForegroundColor Green
        Write-Host "  Nome: $($chatIds[$chatId])" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "Use o Chat ID do grupo desejado no proximo passo!" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
