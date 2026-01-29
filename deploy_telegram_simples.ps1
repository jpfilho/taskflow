# =========================================
# DEPLOY TELEGRAM EDGE FUNCTIONS - SIMPLIFICADO
# =========================================

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host " DEPLOY TELEGRAM EDGE FUNCTIONS" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$SSHUser = "root"
$SSHHost = "212.85.0.249"
$SupabasePath = "/root/supabase"

# =========================================
# 1. CRIAR DIRETORIOS
# =========================================

Write-Host "Criando diretorios no servidor..." -ForegroundColor Yellow

ssh "${SSHUser}@${SSHHost}" "mkdir -p ${SupabasePath}/volumes/functions/telegram-webhook"
ssh "${SSHUser}@${SSHHost}" "mkdir -p ${SupabasePath}/volumes/functions/telegram-send"

Write-Host "Diretorios criados!" -ForegroundColor Green
Write-Host ""

# =========================================
# 2. COPIAR ARQUIVOS
# =========================================

Write-Host "Copiando arquivos para o servidor..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  -> telegram-webhook/index.ts" -ForegroundColor Gray
scp -r "supabase\functions\telegram-webhook\*" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"

Write-Host "  -> telegram-webhook/.env" -ForegroundColor Gray
scp "supabase\functions\telegram-webhook\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"

Write-Host "  -> telegram-send/index.ts" -ForegroundColor Gray
scp -r "supabase\functions\telegram-send\*" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"

Write-Host "  -> telegram-send/.env" -ForegroundColor Gray
scp "supabase\functions\telegram-send\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"

Write-Host ""
Write-Host "Arquivos copiados!" -ForegroundColor Green
Write-Host ""

# =========================================
# 3. REINICIAR CONTAINER
# =========================================

Write-Host "Reiniciando container edge-functions..." -ForegroundColor Yellow

ssh "${SSHUser}@${SSHHost}" "docker-compose -f ${SupabasePath}/docker-compose.yml restart edge-functions"

Write-Host "Container reiniciado!" -ForegroundColor Green
Write-Host ""

# =========================================
# 4. AGUARDAR INICIALIZACAO
# =========================================

Write-Host "Aguardando 5 segundos..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# =========================================
# 5. VERIFICAR LOGS
# =========================================

Write-Host "Verificando logs..." -ForegroundColor Yellow
Write-Host ""

ssh "${SSHUser}@${SSHHost}" "docker-compose -f ${SupabasePath}/docker-compose.yml logs --tail=30 edge-functions"

Write-Host ""

# =========================================
# 6. TESTAR ENDPOINTS
# =========================================

Write-Host "Testando endpoints..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  -> telegram-webhook" -ForegroundColor Gray
curl.exe -k -s "https://212.85.0.249/functions/v1/telegram-webhook" | Select-Object -First 100

Write-Host ""
Write-Host "  -> telegram-send" -ForegroundColor Gray
curl.exe -k -s "https://212.85.0.249/functions/v1/telegram-send" | Select-Object -First 100

Write-Host ""

# =========================================
# CONCLUÍDO
# =========================================

Write-Host "DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Configurar webhook do Telegram:" -ForegroundColor White
Write-Host "   .\configurar_webhook.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Executar migration SQL:" -ForegroundColor White
Write-Host "   Via Supabase Studio ou psql" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Testar integracao no app Flutter" -ForegroundColor White
Write-Host ""
