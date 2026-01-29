# =========================================
# DEPLOY TELEGRAM - VERSAO FINAL CORRIGIDA
# =========================================

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host " DEPLOY TELEGRAM - VERSAO FINAL" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$SSHUser = "root"
$SSHHost = "212.85.0.249"
$SupabasePath = "/root/supabase"

# =========================================
# PREPARAR ARQUIVOS .ENV LOCALMENTE
# =========================================

Write-Host "Preparando arquivos .env..." -ForegroundColor Cyan

# Renomear env_file.txt para .env
Copy-Item "supabase\functions\telegram-webhook\env_file.txt" "supabase\functions\telegram-webhook\.env" -Force
Copy-Item "supabase\functions\telegram-send\env_file.txt" "supabase\functions\telegram-send\.env" -Force

Write-Host "OK - Arquivos .env criados localmente!" -ForegroundColor Green
Write-Host ""

# =========================================
# CRIAR DIRETORIOS NO SERVIDOR
# =========================================

Write-Host "Criando diretorios no servidor..." -ForegroundColor Cyan

ssh ${SSHUser}@${SSHHost} "mkdir -p ${SupabasePath}/volumes/functions/telegram-webhook; mkdir -p ${SupabasePath}/volumes/functions/telegram-send; echo OK"

Write-Host "OK - Diretorios criados!" -ForegroundColor Green
Write-Host ""

# =========================================
# COPIAR telegram-webhook
# =========================================

Write-Host "Copiando telegram-webhook..." -ForegroundColor Cyan

scp "supabase\functions\telegram-webhook\index.ts" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"
scp "supabase\functions\telegram-webhook\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"

Write-Host "OK - telegram-webhook copiado!" -ForegroundColor Green
Write-Host ""

# =========================================
# COPIAR telegram-send
# =========================================

Write-Host "Copiando telegram-send..." -ForegroundColor Cyan

scp "supabase\functions\telegram-send\index.ts" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"
scp "supabase\functions\telegram-send\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"

Write-Host "OK - telegram-send copiado!" -ForegroundColor Green
Write-Host ""

# =========================================
# VERIFICAR ARQUIVOS NO SERVIDOR
# =========================================

Write-Host "Verificando arquivos copiados..." -ForegroundColor Cyan
Write-Host ""

ssh ${SSHUser}@${SSHHost} "echo '=== telegram-webhook ===' && ls -la ${SupabasePath}/volumes/functions/telegram-webhook/ && echo '' && echo '=== telegram-send ===' && ls -la ${SupabasePath}/volumes/functions/telegram-send/"

Write-Host ""

# =========================================
# REINICIAR CONTAINER
# =========================================

Write-Host "Reiniciando container edge-functions..." -ForegroundColor Cyan

ssh ${SSHUser}@${SSHHost} "cd ${SupabasePath}; docker-compose restart edge-functions; echo 'Aguardando...'; sleep 5"

Write-Host "OK - Container reiniciado!" -ForegroundColor Green
Write-Host ""

# =========================================
# VERIFICAR LOGS
# =========================================

Write-Host "Verificando logs..." -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Gray

ssh ${SSHUser}@${SSHHost} "cd ${SupabasePath}; docker-compose logs --tail=50 edge-functions | grep -i 'telegram\|error\|started' || docker-compose logs --tail=50 edge-functions"

Write-Host "=======================================" -ForegroundColor Gray
Write-Host ""

# =========================================
# TESTAR ENDPOINTS
# =========================================

Write-Host "Testando endpoints..." -ForegroundColor Cyan
Write-Host ""

Write-Host "telegram-webhook:" -ForegroundColor Yellow
try {
    $response = curl.exe -k -s -w "`n%{http_code}" "https://212.85.0.249/functions/v1/telegram-webhook" 2>&1 | Select-Object -Last 1
    Write-Host "  Status HTTP: $response" -ForegroundColor $(if ($response -match "40[0-9]|50[0-9]") { "Yellow" } else { "Green" })
} catch {
    Write-Host "  Erro ao testar" -ForegroundColor Red
}

Write-Host ""
Write-Host "telegram-send:" -ForegroundColor Yellow
try {
    $response = curl.exe -k -s -w "`n%{http_code}" "https://212.85.0.249/functions/v1/telegram-send" 2>&1 | Select-Object -Last 1
    Write-Host "  Status HTTP: $response" -ForegroundColor $(if ($response -match "40[0-9]|50[0-9]") { "Yellow" } else { "Green" })
} catch {
    Write-Host "  Erro ao testar" -ForegroundColor Red
}

Write-Host ""

# =========================================
# CONCLUIDO
# =========================================

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host " DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Configurar webhook:" -ForegroundColor White
Write-Host "   .\configurar_webhook.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Executar migration SQL:" -ForegroundColor White
Write-Host "   https://212.85.0.249 (Supabase Studio)" -ForegroundColor Gray
Write-Host "   Execute: supabase\migrations\20260124_telegram_integration.sql" -ForegroundColor Gray
Write-Host ""
