# Script simplificado para obter Chat ID de um grupo do Telegram
# Metodo mais facil: usar o bot @RawDataBot

Write-Host "COMO OBTER O CHAT ID DE UM GRUPO DO TELEGRAM" -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "METODO MAIS FACIL (RECOMENDADO):" -ForegroundColor Green
Write-Host ""
Write-Host "1. Abra o Telegram e va para o grupo" -ForegroundColor White
Write-Host "2. Adicione o bot @RawDataBot ao grupo" -ForegroundColor White
Write-Host "3. O bot automaticamente enviara uma mensagem com todas as informacoes" -ForegroundColor White
Write-Host "4. Procure na mensagem por: id: -1001234567890" -ForegroundColor White
Write-Host "5. O numero negativo e o Chat ID do grupo" -ForegroundColor White
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "METODO ALTERNATIVO - Verificar Logs do Webhook:" -ForegroundColor Green
Write-Host ""
Write-Host "1. Envie uma mensagem no grupo (pode ser qualquer coisa)" -ForegroundColor White
Write-Host "2. Execute: .\ver_logs_vinculacao.ps1" -ForegroundColor Yellow
Write-Host "3. Procure por 'chat_id' ou 'chat.id' nos logs" -ForegroundColor White
Write-Host "4. O valor sera algo como: -1001234567890" -ForegroundColor White
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "METODO ALTERNATIVO - Usar Bot Auxiliar:" -ForegroundColor Green
Write-Host ""
Write-Host "Bots uteis que mostram Chat IDs:" -ForegroundColor White
Write-Host "   - @RawDataBot - Mostra todas as informacoes do grupo" -ForegroundColor Cyan
Write-Host "   - @userinfobot - Mostra informacoes do chat atual" -ForegroundColor Cyan
Write-Host "   - @getidsbot - Mostra IDs de usuarios e grupos" -ForegroundColor Cyan
Write-Host "   - @chatid_robot - Especializado em mostrar Chat IDs" -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "DICA:" -ForegroundColor Green
Write-Host ""
Write-Host "Chat IDs de grupos sao sempre numeros NEGATIVOS:" -ForegroundColor White
Write-Host "   - Grupos normais: -123456789" -ForegroundColor Yellow
Write-Host "   - Supergrupos: -1001234567890 (comecam com -100)" -ForegroundColor Yellow
Write-Host "   - Canais: -1001234567890 (comecam com -100)" -ForegroundColor Yellow
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Precisa de ajuda? Execute:" -ForegroundColor Green
Write-Host "   .\obter_info_grupo_telegram.ps1 -ChatId -1001234567890" -ForegroundColor Yellow
Write-Host "   (Substitua -1001234567890 pelo ID que voce suspeita)" -ForegroundColor Gray
Write-Host ""
