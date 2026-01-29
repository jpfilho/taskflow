# ============================================
# CRIAR SUBSCRIPTION TELEGRAM - CORRIGIDO
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CRIAR SUBSCRIPTION TELEGRAM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Obter Chat ID dos logs
Write-Host "1. Obtendo Chat ID dos logs..." -ForegroundColor Yellow
$chatIdRaw = ssh $SERVER "journalctl -u telegram-webhook -n 50 --no-pager | grep -oP '(?<=\""chat\"":)\{?\""?id\""?:\s*-?\d+' | grep -oP '(?<=id\"":)\s*-?\d+' | tail -1"
$chatId = $chatIdRaw.Trim()

if ([string]::IsNullOrWhiteSpace($chatId) -or $chatId -eq "{") {
    Write-Host "   ERRO: Chat ID nao encontrado!" -ForegroundColor Red
    Write-Host "   Envie uma mensagem no Telegram primeiro!" -ForegroundColor Yellow
    exit
}

Write-Host "   Chat ID: $chatId" -ForegroundColor Green

# 2. Obter grupo existente
Write-Host ""
Write-Host "2. Obtendo grupo existente..." -ForegroundColor Yellow
$grupoIdRaw = ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -t -c 'SELECT id FROM grupos_chat ORDER BY created_at DESC LIMIT 1;'"
$grupoId = $grupoIdRaw.Trim()

if ([string]::IsNullOrWhiteSpace($grupoId)) {
    Write-Host "   ERRO: Nenhum grupo encontrado!" -ForegroundColor Red
    exit
}

Write-Host "   Grupo ID: $grupoId" -ForegroundColor Green

# 3. Copiar script bash
Write-Host ""
Write-Host "3. Copiando script..." -ForegroundColor Yellow
scp criar_subscription.sh "${SERVER}:/root/"
ssh $SERVER "chmod +x /root/criar_subscription.sh"

# 4. Executar criacao
Write-Host ""
Write-Host "4. Criando subscription..." -ForegroundColor Yellow
ssh $SERVER "/root/criar_subscription.sh $chatId $grupoId"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "PRONTO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Chat ID: $chatId" -ForegroundColor White
Write-Host "Grupo ID: $grupoId" -ForegroundColor White
Write-Host ""
Write-Host "TESTE AGORA:" -ForegroundColor Yellow
Write-Host "  1. Envie uma mensagem no Telegram" -ForegroundColor White
Write-Host "  2. Execute: .\verificar_mensagens_banco.ps1" -ForegroundColor White
Write-Host "  3. Verifique se apareceu no banco!" -ForegroundColor White
Write-Host ""
Write-Host "OU TESTE AO CONTRARIO:" -ForegroundColor Yellow
Write-Host "  1. Envie mensagem no chat do app" -ForegroundColor White
Write-Host "  2. Verifique se aparece no Telegram!" -ForegroundColor White
Write-Host ""
