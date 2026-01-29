# ============================================
# OBTER CHAT_ID DO TELEGRAM
# ============================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DESCOBRIR CHAT_ID DO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Solicitar o token
Write-Host "Digite o TOKEN do seu bot do Telegram:" -ForegroundColor Yellow
Write-Host "(Exemplo: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz)" -ForegroundColor Gray
$BOT_TOKEN = Read-Host "Token"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "IMPORTANTE - SIGA ESTES PASSOS:" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Adicione o bot ao grupo (se ainda nao adicionou)" -ForegroundColor White
Write-Host "2. Envie UMA MENSAGEM no grupo (pode ser qualquer coisa)" -ForegroundColor White
Write-Host "3. Pressione ENTER aqui para buscar o Chat ID" -ForegroundColor White
Write-Host ""
Write-Host -NoNewline "Pressione ENTER quando tiver enviado a mensagem... " -ForegroundColor Cyan
$null = Read-Host

Write-Host ""
Write-Host "Buscando informacoes do Telegram..." -ForegroundColor Yellow

try {
    $url = "https://api.telegram.org/bot$BOT_TOKEN/getUpdates"
    $response = Invoke-RestMethod -Uri $url -Method Get
    
    if ($response.ok -and $response.result.Count -gt 0) {
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "CHAT IDs ENCONTRADOS:" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host ""
        
        $chatIds = @{}
        
        foreach ($update in $response.result) {
            if ($update.message) {
                $chat = $update.message.chat
                $chatId = $chat.id
                $chatTitle = $chat.title
                $chatType = $chat.type
                
                if (-not $chatIds.ContainsKey($chatId)) {
                    $chatIds[$chatId] = @{
                        title = $chatTitle
                        type = $chatType
                    }
                }
            }
        }
        
        foreach ($chatId in $chatIds.Keys) {
            $info = $chatIds[$chatId]
            Write-Host "Chat ID: $chatId" -ForegroundColor Yellow
            Write-Host "  Nome: $($info.title)" -ForegroundColor Gray
            Write-Host "  Tipo: $($info.type)" -ForegroundColor Gray
            Write-Host ""
        }
        
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "QUAL USAR?" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "- Para GRUPOS/SUPERGRUPOS: Use o ID que comeca com -100" -ForegroundColor White
        Write-Host "- Para DM (mensagens diretas): Use o ID positivo" -ForegroundColor White
        Write-Host ""
        Write-Host "Copie o Chat ID desejado e use no proximo script!" -ForegroundColor Green
        Write-Host ""
        
        # Salvar em arquivo
        $output = "# CHAT IDs ENCONTRADOS`n`n"
        foreach ($chatId in $chatIds.Keys) {
            $info = $chatIds[$chatId]
            $output += "Chat ID: $chatId`n"
            $output += "  Nome: $($info.title)`n"
            $output += "  Tipo: $($info.type)`n`n"
        }
        
        $output | Out-File -FilePath "telegram_chat_ids.txt" -Encoding UTF8
        Write-Host "Informacoes salvas em: telegram_chat_ids.txt" -ForegroundColor Gray
        Write-Host ""
        
    } else {
        Write-Host ""
        Write-Host "Nenhuma mensagem encontrada!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Certifique-se de:" -ForegroundColor Yellow
        Write-Host "  1. O bot foi adicionado ao grupo" -ForegroundColor White
        Write-Host "  2. Voce enviou uma mensagem no grupo APOS adicionar o bot" -ForegroundColor White
        Write-Host "  3. O token do bot esta correto" -ForegroundColor White
        Write-Host ""
        Write-Host "Tente novamente!" -ForegroundColor Yellow
        Write-Host ""
    }
    
} catch {
    Write-Host ""
    Write-Host "ERRO ao conectar com o Telegram!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Detalhes do erro:" -ForegroundColor Yellow
    Write-Host $_ -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifique se o token do bot esta correto!" -ForegroundColor Yellow
    Write-Host ""
}
