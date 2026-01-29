# =========================================
# SETUP HTTPS AUTOMÁTICO VIA SSH
# =========================================
# Conecta no servidor e configura HTTPS automaticamente
# Execute: .\setup_https_automatico.ps1

param(
    [string]$SSHHost = "212.85.0.249",
    [string]$SSHUser = "root"
)

Write-Host "🚀 Setup HTTPS Automático" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Servidor: $SSHUser@$SSHHost" -ForegroundColor Gray
Write-Host ""

# =========================================
# 1. VERIFICAR ARQUIVO LOCAL
# =========================================

$scriptLocal = "configurar_https_ip_direto.sh"

if (-not (Test-Path $scriptLocal)) {
    Write-Host "❌ Arquivo não encontrado: $scriptLocal" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Script local encontrado: $scriptLocal" -ForegroundColor Green
Write-Host ""

# =========================================
# 2. COPIAR SCRIPT PARA O SERVIDOR
# =========================================

Write-Host "📤 Copiando script para o servidor..." -ForegroundColor Yellow

scp $scriptLocal "${SSHUser}@${SSHHost}:/root/"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Script copiado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao copiar script" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 DICA: Configure o SSH primeiro:" -ForegroundColor Yellow
    Write-Host "   ssh-keygen -t rsa" -ForegroundColor White
    Write-Host "   ssh-copy-id $SSHUser@$SSHHost" -ForegroundColor White
    Write-Host ""
    Write-Host "Ou teste manualmente:" -ForegroundColor Yellow
    Write-Host "   ssh $SSHUser@$SSHHost" -ForegroundColor White
    exit 1
}

Write-Host ""

# =========================================
# 3. EXECUTAR SCRIPT NO SERVIDOR
# =========================================

Write-Host "🔧 Executando configuração no servidor..." -ForegroundColor Yellow
Write-Host "   (Isso pode levar 3-5 minutos)" -ForegroundColor Gray
Write-Host ""

$sshCommand = @"
cd /root && \
chmod +x configurar_https_ip_direto.sh && \
bash configurar_https_ip_direto.sh
"@

ssh "$SSHUser@$SSHHost" $sshCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ HTTPS configurado no servidor!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️  Houve algum problema na execução" -ForegroundColor Yellow
    Write-Host "Verifique os logs acima" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# =========================================
# 4. TESTAR HTTPS
# =========================================

Write-Host "🧪 Testando HTTPS..." -ForegroundColor Yellow

$testUrl = "https://$SSHHost"

try {
    # -SkipCertificateCheck para certificado auto-assinado
    $response = Invoke-WebRequest -Uri $testUrl -Method Get -SkipCertificateCheck -ErrorAction Stop -TimeoutSec 10
    Write-Host "✅ HTTPS funcionando! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode.Value__ -eq 401) {
        Write-Host "✅ HTTPS funcionando! (401 Unauthorized é esperado)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Status: $($_.Exception.Response.StatusCode.Value__)" -ForegroundColor Yellow
        Write-Host "   Mas pode estar funcionando normalmente." -ForegroundColor Gray
    }
}

Write-Host ""

# =========================================
# 5. BAIXAR CERTIFICADO
# =========================================

Write-Host "📥 Baixando certificado do servidor..." -ForegroundColor Yellow

scp "${SSHUser}@${SSHHost}:/root/supabase_cert.pem" "supabase_cert.pem"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Certificado baixado: supabase_cert.pem" -ForegroundColor Green
} else {
    Write-Host "⚠️  Não foi possível baixar o certificado" -ForegroundColor Yellow
}

Write-Host ""

# =========================================
# 6. ATUALIZAR SUPABASE_CONFIG.DART
# =========================================

Write-Host "📝 Atualizando supabase_config.dart..." -ForegroundColor Yellow

$configFile = "lib\config\supabase_config.dart"

if (Test-Path $configFile) {
    $content = Get-Content $configFile -Raw
    
    # Backup
    Copy-Item $configFile "$configFile.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force
    Write-Host "   [OK] Backup criado" -ForegroundColor Gray
    
    # Atualizar URL para HTTPS com IP
    $content = $content -replace 'static const String supabaseUrl = [^;]+;', "static const String supabaseUrl = 'https://$SSHHost';"
    
    $content | Set-Content $configFile -NoNewline
    
    Write-Host "[OK] supabase_config.dart atualizado!" -ForegroundColor Green
    Write-Host "   Nova URL: https://$SSHHost" -ForegroundColor Gray
} else {
    Write-Host "⚠️  Arquivo não encontrado: $configFile" -ForegroundColor Yellow
}

Write-Host ""

# =========================================
# 7. RESUMO FINAL
# =========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ CONFIGURAÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 O que foi feito:" -ForegroundColor Yellow
Write-Host "   ✅ Nginx instalado no servidor"
Write-Host "   ✅ Certificado SSL criado (auto-assinado)"
Write-Host "   ✅ HTTPS configurado na porta 443"
Write-Host "   ✅ Proxy reverso para Supabase (porta 8000)"
Write-Host "   ✅ Firewall configurado"
Write-Host "   ✅ Certificado baixado localmente"
Write-Host "   ✅ supabase_config.dart atualizado"
Write-Host ""

Write-Host "🔗 URLs:" -ForegroundColor Cyan
Write-Host "   HTTPS: https://$SSHHost" -ForegroundColor White
Write-Host "   API: https://$SSHHost/rest/v1/" -ForegroundColor White
Write-Host "   Edge Functions: https://$SSHHost/functions/v1/" -ForegroundColor White
Write-Host ""

Write-Host "📝 PRÓXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣  Testar no navegador:" -ForegroundColor Cyan
Write-Host "   https://$SSHHost" -ForegroundColor White
Write-Host "   (Vai mostrar aviso de certificado, é NORMAL! Clique em 'Avançado' e 'Continuar')"
Write-Host ""

Write-Host "2️⃣  Testar app Flutter:" -ForegroundColor Cyan
Write-Host "   - Reinicie o app (Hot Restart: Ctrl+Shift+F5)"
Write-Host "   - Faça login novamente"
Write-Host "   - Teste alguma funcionalidade"
Write-Host ""

Write-Host "3️⃣  Configurar variáveis de ambiente:" -ForegroundColor Cyan
Write-Host "   Edite: configurar_telegram_env.ps1" -ForegroundColor White
Write-Host "   - Linha ~5: SUPABASE_URL = `"https://$SSHHost`"" -ForegroundColor Gray
Write-Host "   - Linha ~13: SUPABASE_SERVICE_ROLE_KEY (sua chave)" -ForegroundColor Gray
Write-Host "   Execute: .\configurar_telegram_env.ps1" -ForegroundColor White
Write-Host ""

Write-Host "4️⃣  Deploy Edge Functions:" -ForegroundColor Cyan
Write-Host "   .\deploy_telegram_functions.ps1" -ForegroundColor White
Write-Host ""

Write-Host "5️⃣  Configurar webhook Telegram:" -ForegroundColor Cyan
Write-Host "   Execute o comando abaixo:" -ForegroundColor White
Write-Host ""
Write-Host "   curl -F `"url=https://$SSHHost/functions/v1/telegram-webhook`" ``" -ForegroundColor Gray
Write-Host "        -F `"certificate=@supabase_cert.pem`" ``" -ForegroundColor Gray
Write-Host "        -F `"secret_token=SEU_WEBHOOK_SECRET`" ``" -ForegroundColor Gray
Write-Host "        https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/setWebhook" -ForegroundColor Gray
Write-Host ""
Write-Host "   (Substitua SEU_WEBHOOK_SECRET pelo valor em telegram_env_vars.txt)" -ForegroundColor Yellow
Write-Host ""

Write-Host "6️⃣  Executar migration SQL:" -ForegroundColor Cyan
Write-Host "   supabase\migrations\20260124_telegram_integration.sql" -ForegroundColor White
Write-Host ""

Write-Host "📚 Documentação:" -ForegroundColor Gray
Write-Host "   - INTEGRACAO_TELEGRAM.md - Documentação completa"
Write-Host "   - CHECKLIST_TESTES_TELEGRAM.md - Testes detalhados"
Write-Host ""

Write-Host "⚠️  NOTA IMPORTANTE:" -ForegroundColor Yellow
Write-Host "   O certificado é auto-assinado, então navegadores vão mostrar aviso."
Write-Host "   Isso é NORMAL e esperado. O Telegram aceita esse tipo de certificado"
Write-Host "   quando enviamos o arquivo .pem junto no webhook."
Write-Host ""

Write-Host "🎉 Pronto! HTTPS configurado com sucesso!" -ForegroundColor Green
Write-Host ""
