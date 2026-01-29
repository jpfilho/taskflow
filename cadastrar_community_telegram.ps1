# ============================================
# CADASTRAR SUPERGRUPO - MODO DIRETO (POWERSHELL)
# ============================================

$SERVER = "root@212.85.0.249"

# Função para listar comunidades
function Listar-Comunidades {
  Write-Host ""
  Write-Host "Comunidades disponíveis:" -ForegroundColor Cyan
  Write-Host ""
  
  $query = @"
SELECT 
    id,
    divisao_nome,
    segmento_nome,
    CASE 
        WHEN tc.telegram_chat_id IS NOT NULL THEN 'Configurado'
        ELSE 'Nao configurado'
    END as status_telegram
FROM comunidades c
LEFT JOIN telegram_communities tc ON tc.community_id = c.id
ORDER BY divisao_nome, segmento_nome
LIMIT 20;
"@
  
  ssh $SERVER "docker exec supabase-db psql -U postgres -d postgres -c `"$query`""
}

# Se não passou parâmetros, mostrar ajuda e listar
if ($args.Count -eq 0) {
  Write-Host ""
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host "CADASTRAR SUPERGRUPO TELEGRAM" -ForegroundColor Cyan
  Write-Host "==========================================" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Uso:" -ForegroundColor Yellow
  Write-Host "  .\cadastrar_community_telegram.ps1 <community_id> <telegram_chat_id>" -ForegroundColor White
  Write-Host ""
  Write-Host "Exemplo:" -ForegroundColor Yellow
  Write-Host "  .\cadastrar_community_telegram.ps1 1a8afda9-9b15-4985-bc30-423f2458623c -1003721115749" -ForegroundColor White
  Write-Host ""
  
  Listar-Comunidades
  
  Write-Host ""
  Write-Host "Ou use o modo interativo:" -ForegroundColor Yellow
  Write-Host "  .\cadastrar_community_interativo.ps1" -ForegroundColor White
  Write-Host ""
  exit 0
}

# Se passou parâmetros, executar cadastro
if ($args.Count -lt 2) {
  Write-Host ""
  Write-Host "❌ Parâmetros insuficientes!" -ForegroundColor Red
  Write-Host ""
  Write-Host "Uso: .\cadastrar_community_telegram.ps1 <community_id> <telegram_chat_id>" -ForegroundColor Yellow
  Write-Host ""
  Listar-Comunidades
  exit 1
}

$COMMUNITY_ID = $args[0]
$TELEGRAM_CHAT_ID = $args[1]

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CADASTRAR SUPERGRUPO PARA COMUNIDADE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Community ID: $COMMUNITY_ID" -ForegroundColor Yellow
Write-Host "Telegram Chat ID: $TELEGRAM_CHAT_ID" -ForegroundColor Yellow
Write-Host ""

Write-Host "Copiando script..." -ForegroundColor Yellow
scp cadastrar_community_telegram.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando cadastro..." -ForegroundColor Yellow
ssh $SERVER "chmod +x /root/cadastrar_community_telegram.sh && /root/cadastrar_community_telegram.sh $COMMUNITY_ID $TELEGRAM_CHAT_ID"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CADASTRO CONCLUÍDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
