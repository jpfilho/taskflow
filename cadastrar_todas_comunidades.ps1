# ============================================
# CADASTRAR TODAS AS COMUNIDADES FALTANTES
# ============================================

$SERVER = "root@212.85.0.249"

# Chat ID padrão (pode ser passado como parâmetro)
$TELEGRAM_CHAT_ID = if ($args.Count -gt 0) { $args[0] } else { "-1003721115749" }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CADASTRAR COMUNIDADES FALTANTES" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Telegram Chat ID: $TELEGRAM_CHAT_ID" -ForegroundColor Yellow
Write-Host ""
Write-Host "Este script irá cadastrar todas as comunidades que ainda não têm supergrupo configurado." -ForegroundColor White
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp cadastrar_todas_comunidades.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando cadastro..." -ForegroundColor Yellow
ssh -t $SERVER "chmod +x /root/cadastrar_todas_comunidades.sh && /root/cadastrar_todas_comunidades.sh $TELEGRAM_CHAT_ID"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "PROCESSO CONCLUÍDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
