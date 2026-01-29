# =========================================
# DEPLOY EDGE FUNCTIONS - TELEGRAM
# =========================================
# Para Supabase Docker na Hostinger VPS
# Execute: .\deploy_telegram_functions.ps1

param(
    [string]$SSHUser = "root",
    [string]$SSHHost = "srv750497.hstgr.cloud",
    [string]$SupabasePath = "/opt/supabase"
)

Write-Host "🚀 Deploy das Edge Functions Telegram" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# =========================================
# 1. VERIFICAR ARQUIVOS LOCAIS
# =========================================

Write-Host "📋 Verificando arquivos locais..." -ForegroundColor Yellow

$localFunctions = @(
    "supabase\functions\telegram-webhook\index.ts",
    "supabase\functions\telegram-webhook\.env",
    "supabase\functions\telegram-send\index.ts",
    "supabase\functions\telegram-send\.env"
)

$allFilesExist = $true
foreach ($file in $localFunctions) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $file não encontrado" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "❌ Alguns arquivos não foram encontrados!" -ForegroundColor Red
    Write-Host "Execute primeiro: .\configurar_telegram_env.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "✅ Todos os arquivos locais estão OK!" -ForegroundColor Green
Write-Host ""

# =========================================
# 2. CONFIRMAR DEPLOY
# =========================================

Write-Host "📡 Configuração de Deploy:" -ForegroundColor Cyan
Write-Host "   SSH: $SSHUser@$SSHHost"
Write-Host "   Caminho remoto: $SupabasePath/volumes/functions/"
Write-Host ""

$confirm = Read-Host "Deseja continuar com o deploy? (s/N)"
if ($confirm -ne "s" -and $confirm -ne "S") {
    Write-Host "❌ Deploy cancelado." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# =========================================
# 3. CRIAR DIRETÓRIOS NO SERVIDOR
# =========================================

Write-Host "📁 Criando diretórios no servidor..." -ForegroundColor Yellow

$createDirsCmd = "mkdir -p $SupabasePath/volumes/functions/telegram-webhook; mkdir -p $SupabasePath/volumes/functions/telegram-send; echo 'Diretorios criados com sucesso'"

Write-Host "Executando: ssh $SSHUser@$SSHHost ..." -ForegroundColor Gray
ssh "$SSHUser@$SSHHost" $createDirsCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Erro ao criar diretórios no servidor" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 DICA: Verifique se:" -ForegroundColor Yellow
    Write-Host "   - Você tem acesso SSH configurado"
    Write-Host "   - O caminho $SupabasePath está correto"
    Write-Host "   - Execute: ssh $SSHUser@$SSHHost 'ls -la /opt/'"
    Write-Host ""
    exit 1
}

Write-Host ""

# =========================================
# 4. COPIAR ARQUIVOS VIA SCP
# =========================================

Write-Host "📤 Copiando arquivos para o servidor..." -ForegroundColor Yellow
Write-Host ""

# Copiar telegram-webhook
Write-Host "   📦 Copiando telegram-webhook..." -ForegroundColor Cyan
scp -r "supabase\functions\telegram-webhook" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/"

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ telegram-webhook copiado" -ForegroundColor Green
} else {
    Write-Host "   ❌ Erro ao copiar telegram-webhook" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Copiar telegram-send
Write-Host "   📦 Copiando telegram-send..." -ForegroundColor Cyan
scp -r "supabase\functions\telegram-send" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/"

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ telegram-send copiado" -ForegroundColor Green
} else {
    Write-Host "   ❌ Erro ao copiar telegram-send" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Arquivos copiados com sucesso!" -ForegroundColor Green
Write-Host ""

# =========================================
# 5. VERIFICAR ARQUIVOS NO SERVIDOR
# =========================================

Write-Host "🔍 Verificando arquivos no servidor..." -ForegroundColor Yellow

$verifyCmd = @"
echo '=== telegram-webhook ===' && \
ls -la $SupabasePath/volumes/functions/telegram-webhook/ && \
echo '' && \
echo '=== telegram-send ===' && \
ls -la $SupabasePath/volumes/functions/telegram-send/
"@

ssh "$SSHUser@$SSHHost" $verifyCmd

Write-Host ""

# =========================================
# 6. AJUSTAR PERMISSÕES
# =========================================

Write-Host "🔐 Ajustando permissões..." -ForegroundColor Yellow

$permissionsCmd = @"
chmod -R 755 $SupabasePath/volumes/functions/ && \
chown -R 1000:1000 $SupabasePath/volumes/functions/ && \
echo 'Permissoes ajustadas'
"@

ssh "$SSHUser@$SSHHost" $permissionsCmd

Write-Host ""

# =========================================
# 7. REINICIAR CONTAINER EDGE FUNCTIONS
# =========================================

Write-Host "🔄 Reiniciando container edge-functions..." -ForegroundColor Yellow

$restartCmd = 'cd ' + $SupabasePath + '; docker-compose restart edge-functions; echo Container reiniciado; sleep 3; docker-compose logs --tail=20 edge-functions'

ssh "$SSHUser@$SSHHost" $restartCmd

Write-Host ""
Write-Host "✅ Container reiniciado!" -ForegroundColor Green
Write-Host ""

# =========================================
# 8. TESTAR ENDPOINT
# =========================================

Write-Host "🧪 Testando endpoint..." -ForegroundColor Yellow
Write-Host ""

$testUrl = "https://$SSHHost/functions/v1/telegram-webhook"
Write-Host "   URL: $testUrl" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri $testUrl -Method Get -SkipCertificateCheck -ErrorAction SilentlyContinue
    Write-Host "   ✅ Endpoint responde! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode.Value__ -eq 401) {
        Write-Host "   ✅ Endpoint OK! (401 Unauthorized é esperado)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Status: $($_.Exception.Response.StatusCode.Value__)" -ForegroundColor Yellow
    }
}

Write-Host ""

# =========================================
# 9. RESUMO
# =========================================

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "✅ DEPLOY CONCLUÍDO COM SUCESSO!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Próximos passos:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣  Configurar webhook do Telegram:" -ForegroundColor Cyan
Write-Host "   .\configurar_webhook.ps1"
Write-Host ""
Write-Host "2️⃣  Verificar webhook:" -ForegroundColor Cyan
Write-Host "   curl `"https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo`""
Write-Host ""
Write-Host "3️⃣  Executar migration SQL:" -ForegroundColor Cyan
Write-Host "   supabase\migrations\20260124_telegram_integration.sql"
Write-Host ""
Write-Host "4️⃣  Testar no app Flutter!" -ForegroundColor Cyan
Write-Host ""
Write-Host "📚 Documentação completa: INTEGRACAO_TELEGRAM.md" -ForegroundColor Gray
Write-Host ""
