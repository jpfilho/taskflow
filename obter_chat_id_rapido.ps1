ls# ============================================
# OBTER CHAT ID RAPIDO
# ============================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "OBTER CHAT ID DO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Buscando ultimas atualizacoes do bot..." -ForegroundColor Yellow
Write-Host ""

$botToken = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"
$url = "https://api.telegram.org/bot$botToken/getUpdates"

$response = Invoke-RestMethod -Uri $url -Method Get

if ($response.ok -and $response.result.Count -gt 0) {
    Write-Host "Chats encontrados:" -ForegroundColor Green
    Write-Host ""
    
    $chats = @{}
    foreach ($update in $response.result) {
        if ($update.message -and $update.message.chat) {
            $chat = $update.message.chat
            $chatId = $chat.id
            $chatTitle = $chat.title
            $chatType = $chat.type
            
            if (-not $chats.ContainsKey($chatId)) {
                $chats[$chatId] = @{
                    title = $chatTitle
                    type = $chatType
                }
            }
        }
    }
    
    foreach ($chatId in $chats.Keys) {
        $chat = $chats[$chatId]
        Write-Host "Chat ID: $chatId" -ForegroundColor White
        Write-Host "  Titulo: $($chat.title)" -ForegroundColor Gray
        Write-Host "  Tipo: $($chat.type)" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($chats.Count -eq 0) {
        Write-Host "Nenhum chat encontrado nas atualizacoes recentes." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "ALTERNATIVA:" -ForegroundColor Cyan
        Write-Host "  1. Adicione @getidsbot ao grupo" -ForegroundColor White
        Write-Host "  2. O bot mostrara o Chat ID" -ForegroundColor White
        Write-Host ""
    }
} else {
    Write-Host "Nenhuma atualizacao encontrada." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "COMO OBTER O CHAT ID:" -ForegroundColor Cyan
    Write-Host "  1. Adicione @getidsbot ao seu grupo do Telegram" -ForegroundColor White
    Write-Host "  2. O bot mostrara automaticamente o Chat ID" -ForegroundColor White
    Write-Host "  3. O Chat ID de grupos sempre comeca com -100" -ForegroundColor White
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
