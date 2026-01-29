# Deploy Edge Functions - Versão Corrigida
Write-Host "Iniciando deploy das Edge Functions..." -ForegroundColor Cyan
Write-Host ""

$SSHUser = "root"
$SSHHost = "212.85.0.249"
$SupabasePath = "/root/supabase"

# =========================================
# 1. CRIAR ESTRUTURA DE PASTAS NO SERVIDOR
# =========================================

Write-Host "Criando estrutura de pastas..." -ForegroundColor Yellow

ssh ${SSHUser}@${SSHHost} @"
mkdir -p ${SupabasePath}/volumes/functions/telegram-webhook
mkdir -p ${SupabasePath}/volumes/functions/telegram-send
ls -la ${SupabasePath}/volumes/functions/
"@

Write-Host ""

# =========================================
# 2. COPIAR telegram-webhook
# =========================================

Write-Host "Copiando telegram-webhook..." -ForegroundColor Yellow

# Copiar index.ts
scp "supabase\functions\telegram-webhook\index.ts" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/index.ts"

# Preparar e copiar .env
Copy-Item "supabase\functions\telegram-webhook\env_file.txt" "supabase\functions\telegram-webhook\.env" -Force
scp "supabase\functions\telegram-webhook\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/.env"

Write-Host ""

# =========================================
# 3. COPIAR telegram-send
# =========================================

Write-Host "Copiando telegram-send..." -ForegroundColor Yellow

# Copiar index.ts
scp "supabase\functions\telegram-send\index.ts" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/index.ts"

# Preparar e copiar .env
Copy-Item "supabase\functions\telegram-send\env_file.txt" "supabase\functions\telegram-send\.env" -Force
scp "supabase\functions\telegram-send\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/.env"

Write-Host ""

# =========================================
# 4. VERIFICAR ARQUIVOS NO SERVIDOR
# =========================================

Write-Host "Verificando arquivos copiados..." -ForegroundColor Yellow
Write-Host ""

ssh ${SSHUser}@${SSHHost} @"
echo '=== telegram-webhook ==='
ls -lah ${SupabasePath}/volumes/functions/telegram-webhook/
echo ''
echo '=== telegram-send ==='
ls -lah ${SupabasePath}/volumes/functions/telegram-send/
echo ''
echo '=== Primeiras linhas de telegram-send/index.ts ==='
head -n 5 ${SupabasePath}/volumes/functions/telegram-send/index.ts
"@

Write-Host ""

# =========================================
# 5. REINICIAR CONTAINER
# =========================================

Write-Host "Reiniciando container edge-functions..." -ForegroundColor Yellow

ssh ${SSHUser}@${SSHHost} "cd ${SupabasePath} && docker-compose restart edge-functions"

Write-Host ""
Write-Host "Aguardando 10 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# =========================================
# 6. VERIFICAR LOGS
# =========================================

Write-Host "Verificando logs..." -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Gray

ssh ${SSHUser}@${SSHHost} "cd ${SupabasePath} && docker-compose logs --tail=50 edge-functions"

Write-Host "=======================================" -ForegroundColor Gray
Write-Host ""

# =========================================
# 7. TESTAR ENDPOINTS
# =========================================

Write-Host "Testando endpoints..." -ForegroundColor Yellow
Write-Host ""

Write-Host "telegram-send:" -ForegroundColor Cyan
curl.exe -k -s "http://212.85.0.249:8000/functions/v1/telegram-send" 2>&1 | Select-Object -First 3

Write-Host ""
Write-Host "telegram-webhook:" -ForegroundColor Cyan
curl.exe -k -s "http://212.85.0.249:8000/functions/v1/telegram-webhook" 2>&1 | Select-Object -First 3

Write-Host ""
Write-Host ""
Write-Host "DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host ""
