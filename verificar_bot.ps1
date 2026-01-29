# ============================================
# VERIFICAR BOT DO TELEGRAM
# ============================================

$BOT_TOKEN = "8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICANDO BOT DO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Buscando informacoes do bot..." -ForegroundColor Yellow

try {
    $url = "https://api.telegram.org/bot$BOT_TOKEN/getMe"
    $response = Invoke-RestMethod -Uri $url -Method Get
    
    if ($response.ok) {
        $bot = $response.result
        
        Write-Host ""
        Write-Host "BOT ENCONTRADO:" -ForegroundColor Green
        Write-Host "  ID: $($bot.id)" -ForegroundColor Gray
        Write-Host "  Username: @$($bot.username)" -ForegroundColor Yellow
        Write-Host "  Nome: $($bot.first_name)" -ForegroundColor Gray
        Write-Host "  Bot: $($bot.is_bot)" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "Link correto para vincular:" -ForegroundColor Cyan
        Write-Host "  https://t.me/$($bot.username)?start=link_USER_ID" -ForegroundColor White
        Write-Host ""
        
        # Salvar
        $config = @"
# BOT INFORMATION
BOT_USERNAME=$($bot.username)
BOT_ID=$($bot.id)
BOT_NAME=$($bot.first_name)
BOT_TOKEN=$BOT_TOKEN
"@
        $config | Out-File -FilePath "bot_info.txt" -Encoding UTF8
        Write-Host "Informacoes salvas em: bot_info.txt" -ForegroundColor Gray
        
    } else {
        Write-Host "ERRO: $($response.description)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERRO ao conectar: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
