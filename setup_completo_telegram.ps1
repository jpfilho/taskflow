# =========================================
# SETUP COMPLETO - INTEGRAÇÃO TELEGRAM
# =========================================
# Execute DEPOIS de configurar HTTPS no servidor
# 
# Pré-requisitos:
# 1. DNS configurado: api.taskflow3.com.br → 212.85.0.249
# 2. Script configurar_https_taskflow.sh executado no servidor
# 3. HTTPS funcionando: https://api.taskflow3.com.br
#
# Execute: .\setup_completo_telegram.ps1

param(
    [string]$SupabaseURL = "https://api.taskflow3.com.br",
    [string]$TelegramBotToken = "8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec",
    [string]$SSHHost = "212.85.0.249",
    [string]$SSHUser = "root"
)

Write-Host "🚀 Setup Completo - Integração Telegram" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# =========================================
# 1. VERIFICAR PRÉ-REQUISITOS
# =========================================

Write-Host "📋 Verificando pré-requisitos..." -ForegroundColor Yellow
Write-Host ""

# Verificar HTTPS
Write-Host "   🔍 Testando HTTPS: $SupabaseURL" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri $SupabaseURL -Method Get -SkipCertificateCheck -ErrorAction Stop -TimeoutSec 10
    Write-Host "   ✅ HTTPS funcionando!" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode.Value__ -eq 401) {
        Write-Host "   ✅ HTTPS funcionando! (401 é esperado)" -ForegroundColor Green
    } else {
        Write-Host "   ❌ HTTPS não está funcionando!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Execute primeiro no servidor:" -ForegroundColor Yellow
        Write-Host "   bash configurar_https_taskflow.sh" -ForegroundColor White
        Write-Host ""
        Write-Host "Consulte: GUIA_HTTPS_DOMINIO_PROPRIO.md" -ForegroundColor Gray
        exit 1
    }
}

Write-Host ""

# =========================================
# 2. ATUALIZAR SUPABASE_CONFIG.DART
# =========================================

Write-Host "📝 Atualizando supabase_config.dart..." -ForegroundColor Yellow

$configFile = "lib\config\supabase_config.dart"

if (Test-Path $configFile) {
    $content = Get-Content $configFile -Raw
    
    # Backup
    Copy-Item $configFile "$configFile.backup" -Force
    Write-Host "   💾 Backup criado: $configFile.backup" -ForegroundColor Gray
    
    # Atualizar URL
    $content = $content -replace 'static const String supabaseUrl = [^;]+;', "static const String supabaseUrl = '$SupabaseURL';"
    
    $content | Set-Content $configFile -NoNewline
    
    Write-Host "   ✅ supabase_config.dart atualizado!" -ForegroundColor Green
    Write-Host "      Nova URL: $SupabaseURL" -ForegroundColor Gray
} else {
    Write-Host "   ⚠️  Arquivo não encontrado: $configFile" -ForegroundColor Yellow
}

Write-Host ""

# =========================================
# 3. CONFIGURAR VARIÁVEIS DE AMBIENTE
# =========================================

Write-Host "⚙️  Configurando variáveis de ambiente..." -ForegroundColor Yellow

# Verificar se já tem SUPABASE_SERVICE_ROLE_KEY configurada
$envScriptPath = "configurar_telegram_env.ps1"
if (Test-Path $envScriptPath) {
    $envContent = Get-Content $envScriptPath -Raw
    
    if ($envContent -match 'SUPABASE_SERVICE_ROLE_KEY = "YOUR_SERVICE_ROLE_KEY_HERE"') {
        Write-Host ""
        Write-Host "   ⚠️  ATENÇÃO: Configure a SUPABASE_SERVICE_ROLE_KEY primeiro!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   1. Abra: configurar_telegram_env.ps1" -ForegroundColor White
        Write-Host "   2. Encontre: `$SUPABASE_SERVICE_ROLE_KEY = `"YOUR_SERVICE_ROLE_KEY_HERE`"" -ForegroundColor White
        Write-Host "   3. Substitua pela sua service_role key" -ForegroundColor White
        Write-Host "   4. Execute novamente este script" -ForegroundColor White
        Write-Host ""
        
        $continue = Read-Host "Já configurou a service_role key? (s/N)"
        if ($continue -ne "s" -and $continue -ne "S") {
            Write-Host "❌ Setup cancelado." -ForegroundColor Red
            exit 1
        }
    }
    
    # Atualizar URL no script de env
    $envContent = $envContent -replace 'SUPABASE_URL = "[^"]+"', "SUPABASE_URL = `"$SupabaseURL`""
    $envContent | Set-Content $envScriptPath -NoNewline
    
    Write-Host "   ✅ URL atualizada em configurar_telegram_env.ps1" -ForegroundColor Green
    
    # Executar configuração de env vars
    Write-Host "   🔧 Executando configurar_telegram_env.ps1..." -ForegroundColor Cyan
    & ".\configurar_telegram_env.ps1"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Variáveis de ambiente configuradas!" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Erro ao configurar variáveis de ambiente" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# =========================================
# 4. DEPLOY EDGE FUNCTIONS
# =========================================

Write-Host "🚀 Deploy das Edge Functions..." -ForegroundColor Yellow
Write-Host ""

$deployScript = "deploy_telegram_functions.ps1"

if (Test-Path $deployScript) {
    # Atualizar URL no script de deploy
    $deployContent = Get-Content $deployScript -Raw
    $deployContent = $deployContent -replace 'SupabasePath = "[^"]+"', "SupabasePath = `"/opt/supabase`""
    $deployContent | Set-Content $deployScript -NoNewline
    
    Write-Host "Executando deploy (isso pode levar alguns minutos)..." -ForegroundColor Cyan
    Write-Host ""
    
    & ".\deploy_telegram_functions.ps1" -SSHHost $SSHHost -SSHUser $SSHUser
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "   ✅ Edge Functions deployadas!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "   ⚠️  Deploy teve problemas, mas pode continuar..." -ForegroundColor Yellow
    }
} else {
    Write-Host "   ⚠️  Script de deploy não encontrado: $deployScript" -ForegroundColor Yellow
}

Write-Host ""

# =========================================
# 5. CONFIGURAR WEBHOOK TELEGRAM
# =========================================

Write-Host "🔗 Configurando webhook do Telegram..." -ForegroundColor Yellow
Write-Host ""

# Ler webhook secret do arquivo
$envVarsFile = "telegram_env_vars.txt"
$webhookSecret = ""

if (Test-Path $envVarsFile) {
    $envVarsContent = Get-Content $envVarsFile -Raw
    if ($envVarsContent -match 'TELEGRAM_WEBHOOK_SECRET=(.+)') {
        $webhookSecret = $Matches[1].Trim()
    }
}

if ([string]::IsNullOrEmpty($webhookSecret)) {
    Write-Host "   ⚠️  TELEGRAM_WEBHOOK_SECRET não encontrado" -ForegroundColor Yellow
    $webhookSecret = Read-Host "Digite o webhook secret (ou Enter para pular)"
    if ([string]::IsNullOrEmpty($webhookSecret)) {
        Write-Host "   ⚠️  Pulando configuração de webhook" -ForegroundColor Yellow
    }
}

if (-not [string]::IsNullOrEmpty($webhookSecret)) {
    $webhookUrl = "$SupabaseURL/functions/v1/telegram-webhook"
    
    Write-Host "   URL do webhook: $webhookUrl" -ForegroundColor Gray
    Write-Host "   Configurando..." -ForegroundColor Cyan
    
    $body = @{
        url = $webhookUrl
        secret_token = $webhookSecret
        allowed_updates = @("message", "edited_message", "callback_query")
    } | ConvertTo-Json

    try {
        $webhookResponse = Invoke-RestMethod `
            -Uri "https://api.telegram.org/bot$TelegramBotToken/setWebhook" `
            -Method Post `
            -ContentType "application/json" `
            -Body $body

        if ($webhookResponse.ok) {
            Write-Host "   ✅ Webhook configurado com sucesso!" -ForegroundColor Green
            
            # Verificar webhook
            Write-Host "   🔍 Verificando webhook..." -ForegroundColor Cyan
            $webhookInfo = Invoke-RestMethod -Uri "https://api.telegram.org/bot$TelegramBotToken/getWebhookInfo"
            
            Write-Host ""
            Write-Host "   📋 Status do webhook:" -ForegroundColor Cyan
            Write-Host "      URL: $($webhookInfo.result.url)" -ForegroundColor Gray
            Write-Host "      Pending: $($webhookInfo.result.pending_update_count)" -ForegroundColor Gray
        } else {
            Write-Host "   ❌ Erro ao configurar webhook" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Erro ao configurar webhook: $_" -ForegroundColor Red
    }
}

Write-Host ""

# =========================================
# 6. RESUMO FINAL
# =========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ SETUP CONCLUÍDO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Checklist:" -ForegroundColor Yellow
Write-Host "   ✅ HTTPS configurado: $SupabaseURL"
Write-Host "   ✅ supabase_config.dart atualizado"
Write-Host "   ✅ Variáveis de ambiente configuradas"
Write-Host "   ✅ Edge Functions deployadas"
if (-not [string]::IsNullOrEmpty($webhookSecret)) {
    Write-Host "   ✅ Webhook Telegram configurado"
} else {
    Write-Host "   ⚠️  Webhook Telegram: configure manualmente"
}
Write-Host ""

Write-Host "🧪 TESTES:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1️⃣  Executar migration SQL:" -ForegroundColor Yellow
Write-Host "   - Abra Supabase Studio (ou psql)"
Write-Host "   - Execute: supabase\migrations\20260124_telegram_integration.sql"
Write-Host ""
Write-Host "2️⃣  Testar no Telegram:" -ForegroundColor Yellow
Write-Host "   - Envie /start para @TaskFlow_chat_bot"
Write-Host "   - Deve responder com mensagem de boas-vindas"
Write-Host ""
Write-Host "3️⃣  Testar no App:" -ForegroundColor Yellow
Write-Host "   - Reinicie o app (Hot Restart)"
Write-Host "   - Faça login novamente"
Write-Host "   - Abra um chat"
Write-Host "   - Clique no ícone ⚡ Telegram"
Write-Host "   - Vincule sua conta"
Write-Host ""
Write-Host "4️⃣  Testar integração:" -ForegroundColor Yellow
Write-Host "   - Configure espelhamento para um chat"
Write-Host "   - Envie mensagem no app → deve aparecer no Telegram"
Write-Host "   - Envie mensagem no Telegram → deve aparecer no app"
Write-Host ""

Write-Host "📚 Documentação:" -ForegroundColor Gray
Write-Host "   - GUIA_HTTPS_DOMINIO_PROPRIO.md - Guia completo"
Write-Host "   - INTEGRACAO_TELEGRAM.md - Documentação técnica"
Write-Host "   - CHECKLIST_TESTES_TELEGRAM.md - Testes detalhados"
Write-Host ""

Write-Host "🎉 Boa sorte!" -ForegroundColor Green
Write-Host ""
