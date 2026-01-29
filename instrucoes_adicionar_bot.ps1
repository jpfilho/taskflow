# ============================================
# VERIFICAR E CORRIGIR BOT NO GRUPO
# ============================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICAR BOT NO GRUPO TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "PROBLEMA IDENTIFICADO:" -ForegroundColor Yellow
Write-Host "  Erro: 'Bad Request: chat not found'" -ForegroundColor Red
Write-Host "  Isso significa que o bot nao esta no grupo ou nao tem permissao" -ForegroundColor White
Write-Host ""

Write-Host "SOLUCAO:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Abra o grupo 'TaskFlow' no Telegram" -ForegroundColor White
Write-Host "2. Clique no nome do grupo (topo)" -ForegroundColor White
Write-Host "3. Vá em 'Adicionar Membros' ou 'Add Members'" -ForegroundColor White
Write-Host "4. Busque: @TaskFlow_chat_bot" -ForegroundColor White
Write-Host "5. Adicione o bot" -ForegroundColor White
Write-Host "6. IMPORTANTE: Torne o bot ADMINISTRADOR do grupo" -ForegroundColor Yellow
Write-Host "   (Configuracoes do grupo > Administradores > Adicionar)" -ForegroundColor Gray
Write-Host ""

Write-Host "OU use este link direto:" -ForegroundColor Cyan
Write-Host "  https://t.me/TaskFlow_chat_bot" -ForegroundColor White
Write-Host "  Depois clique em 'Add to Group' e selecione o grupo 'TaskFlow'" -ForegroundColor Gray
Write-Host ""

Write-Host "DEPOIS DE ADICIONAR:" -ForegroundColor Yellow
Write-Host "  1. Execute: .\testar_endpoint_simples.ps1" -ForegroundColor White
Write-Host "  2. Verifique se a mensagem aparece no Telegram!" -ForegroundColor White
Write-Host ""
