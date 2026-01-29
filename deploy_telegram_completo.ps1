# =========================================
# DEPLOY TELEGRAM - COMPLETO E INTERATIVO
# Execute e digite a senha quando solicitado
# =========================================

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host " DEPLOY TELEGRAM EDGE FUNCTIONS" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$SSHUser = "root"
$SSHHost = "212.85.0.249"
$SupabasePath = "/root/supabase"

Write-Host "Servidor: $SSHHost" -ForegroundColor Yellow
Write-Host "Usuario: $SSHUser" -ForegroundColor Yellow
Write-Host ""
Write-Host "ATENCAO: Voce precisara digitar a senha varias vezes!" -ForegroundColor Yellow
Write-Host ""

# =========================================
# ETAPA 1: CRIAR DIRETORIOS
# =========================================

Write-Host "ETAPA 1/5: Criando diretorios no servidor..." -ForegroundColor Cyan
Write-Host ""

ssh ${SSHUser}@${SSHHost} "mkdir -p ${SupabasePath}/volumes/functions/telegram-webhook && mkdir -p ${SupabasePath}/volumes/functions/telegram-send && echo 'Diretorios criados com sucesso'"

Write-Host ""
Write-Host "OK - Diretorios criados!" -ForegroundColor Green
Write-Host ""

# =========================================
# ETAPA 2: COPIAR ARQUIVOS telegram-webhook
# =========================================

Write-Host "ETAPA 2/5: Copiando arquivos telegram-webhook..." -ForegroundColor Cyan
Write-Host ""

Write-Host "  Copiando index.ts..." -ForegroundColor Gray
scp "supabase\functions\telegram-webhook\index.ts" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"

Write-Host "  Copiando .env..." -ForegroundColor Gray
scp "supabase\functions\telegram-webhook\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"

Write-Host ""
Write-Host "OK - telegram-webhook copiado!" -ForegroundColor Green
Write-Host ""

# =========================================
# ETAPA 3: COPIAR ARQUIVOS telegram-send
# =========================================

Write-Host "ETAPA 3/5: Copiando arquivos telegram-send..." -ForegroundColor Cyan
Write-Host ""

Write-Host "  Copiando index.ts..." -ForegroundColor Gray
scp "supabase\functions\telegram-send\index.ts" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"

Write-Host "  Copiando .env..." -ForegroundColor Gray
scp "supabase\functions\telegram-send\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"

Write-Host ""
Write-Host "OK - telegram-send copiado!" -ForegroundColor Green
Write-Host ""

# =========================================
# ETAPA 4: REINICIAR CONTAINER
# =========================================

Write-Host "ETAPA 4/5: Reiniciando container edge-functions..." -ForegroundColor Cyan
Write-Host ""

ssh ${SSHUser}@${SSHHost} "cd ${SupabasePath} && docker-compose restart edge-functions && echo 'Container reiniciado' && sleep 3"

Write-Host ""
Write-Host "OK - Container reiniciado!" -ForegroundColor Green
Write-Host ""

# =========================================
# ETAPA 5: VERIFICAR LOGS
# =========================================

Write-Host "ETAPA 5/5: Verificando logs..." -ForegroundColor Cyan
Write-Host ""
Write-Host "=======================================" -ForegroundColor Gray

ssh ${SSHUser}@${SSHHost} "docker-compose -f ${SupabasePath}/docker-compose.yml logs --tail=40 edge-functions"

Write-Host "=======================================" -ForegroundColor Gray
Write-Host ""

# =========================================
# TESTAR ENDPOINTS
# =========================================

Write-Host "Testando endpoints..." -ForegroundColor Cyan
Write-Host ""

Write-Host "Testando telegram-webhook:" -ForegroundColor Yellow
curl.exe -k -s "https://212.85.0.249/functions/v1/telegram-webhook" 2>&1 | Select-Object -First 3

Write-Host ""
Write-Host "Testando telegram-send:" -ForegroundColor Yellow
curl.exe -k -s "https://212.85.0.249/functions/v1/telegram-send" 2>&1 | Select-Object -First 3

Write-Host ""

# =========================================
# CONCLUIDO
# =========================================

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host " DEPLOY CONCLUIDO COM SUCESSO!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Configurar webhook do Telegram:" -ForegroundColor White
Write-Host "   .\configurar_webhook.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Executar migration SQL:" -ForegroundColor White
Write-Host "   Abra Supabase Studio: https://212.85.0.249" -ForegroundColor Gray
Write-Host "   Execute: supabase\migrations\20260124_telegram_integration.sql" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Testar integracao no app Flutter" -ForegroundColor White
Write-Host ""
