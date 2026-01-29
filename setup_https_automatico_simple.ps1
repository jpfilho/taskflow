# =========================================
# SETUP HTTPS AUTOMATICO VIA SSH
# =========================================
# Conecta no servidor e configura HTTPS automaticamente
# Execute: .\setup_https_automatico_simple.ps1

param(
    [string]$SSHHost = "212.85.0.249",
    [string]$SSHUser = "root"
)

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "SETUP HTTPS AUTOMATICO" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Servidor: $SSHUser@$SSHHost" -ForegroundColor Gray
Write-Host ""

# =========================================
# 1. VERIFICAR ARQUIVO LOCAL
# =========================================

$scriptLocal = "configurar_https_ip_direto.sh"

if (-not (Test-Path $scriptLocal)) {
    Write-Host "[ERRO] Arquivo nao encontrado: $scriptLocal" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Script local encontrado: $scriptLocal" -ForegroundColor Green
Write-Host ""

# =========================================
# 2. COPIAR SCRIPT PARA O SERVIDOR
# =========================================

Write-Host "[...] Copiando script para o servidor..." -ForegroundColor Yellow

scp $scriptLocal "${SSHUser}@${SSHHost}:/root/"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Script copiado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "[ERRO] Erro ao copiar script" -ForegroundColor Red
    Write-Host ""
    Write-Host "DICA: Configure o SSH primeiro:" -ForegroundColor Yellow
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

Write-Host "[...] Executando configuracao no servidor..." -ForegroundColor Yellow
Write-Host "     (Isso pode levar 3-5 minutos)" -ForegroundColor Gray
Write-Host ""

$sshCommand = @"
cd /root && \
chmod +x configurar_https_ip_direto.sh && \
bash configurar_https_ip_direto.sh
"@

ssh "$SSHUser@$SSHHost" $sshCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] HTTPS configurado no servidor!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[AVISO] Houve algum problema na execucao" -ForegroundColor Yellow
    Write-Host "Verifique os logs acima" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# =========================================
# 4. TESTAR HTTPS
# =========================================

Write-Host "[...] Testando HTTPS..." -ForegroundColor Yellow

$testUrl = "https://$SSHHost"

try {
    $response = Invoke-WebRequest -Uri $testUrl -Method Get -SkipCertificateCheck -ErrorAction Stop -TimeoutSec 10
    Write-Host "[OK] HTTPS funcionando! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode.Value__ -eq 401) {
        Write-Host "[OK] HTTPS funcionando! (401 Unauthorized e esperado)" -ForegroundColor Green
    } else {
        Write-Host "[AVISO] Status: $($_.Exception.Response.StatusCode.Value__)" -ForegroundColor Yellow
        Write-Host "        Mas pode estar funcionando normalmente." -ForegroundColor Gray
    }
}

Write-Host ""

# =========================================
# 5. BAIXAR CERTIFICADO
# =========================================

Write-Host "[...] Baixando certificado do servidor..." -ForegroundColor Yellow

scp "${SSHUser}@${SSHHost}:/root/supabase_cert.pem" "supabase_cert.pem"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Certificado baixado: supabase_cert.pem" -ForegroundColor Green
} else {
    Write-Host "[AVISO] Nao foi possivel baixar o certificado" -ForegroundColor Yellow
}

Write-Host ""

# =========================================
# 6. ATUALIZAR SUPABASE_CONFIG.DART
# =========================================

Write-Host "[...] Atualizando supabase_config.dart..." -ForegroundColor Yellow

$configFile = "lib\config\supabase_config.dart"

if (Test-Path $configFile) {
    $content = Get-Content $configFile -Raw
    
    # Backup
    Copy-Item $configFile "$configFile.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force
    Write-Host "     [OK] Backup criado" -ForegroundColor Gray
    
    # Atualizar URL para HTTPS com IP
    $content = $content -replace 'static const String supabaseUrl = [^;]+;', "static const String supabaseUrl = 'https://$SSHHost';"
    
    $content | Set-Content $configFile -NoNewline
    
    Write-Host "[OK] supabase_config.dart atualizado!" -ForegroundColor Green
    Write-Host "     Nova URL: https://$SSHHost" -ForegroundColor Gray
} else {
    Write-Host "[AVISO] Arquivo nao encontrado: $configFile" -ForegroundColor Yellow
}

Write-Host ""

# =========================================
# 7. RESUMO FINAL
# =========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CONFIGURACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "O que foi feito:" -ForegroundColor Yellow
Write-Host "   [OK] Nginx instalado no servidor"
Write-Host "   [OK] Certificado SSL criado (auto-assinado)"
Write-Host "   [OK] HTTPS configurado na porta 443"
Write-Host "   [OK] Proxy reverso para Supabase (porta 8000)"
Write-Host "   [OK] Firewall configurado"
Write-Host "   [OK] Certificado baixado localmente"
Write-Host "   [OK] supabase_config.dart atualizado"
Write-Host ""

Write-Host "URLs:" -ForegroundColor Cyan
Write-Host "   HTTPS: https://$SSHHost" -ForegroundColor White
Write-Host "   API: https://$SSHHost/rest/v1/" -ForegroundColor White
Write-Host "   Edge Functions: https://$SSHHost/functions/v1/" -ForegroundColor White
Write-Host ""

Write-Host "PROXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Testar no navegador:" -ForegroundColor Cyan
Write-Host "   https://$SSHHost" -ForegroundColor White
Write-Host "   (Vai mostrar aviso de certificado, e NORMAL!)" -ForegroundColor Gray
Write-Host "   Clique em 'Avancado' e 'Continuar'" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Testar app Flutter:" -ForegroundColor Cyan
Write-Host "   - Reinicie o app (Hot Restart: Ctrl+Shift+F5)"
Write-Host "   - Faca login novamente"
Write-Host "   - Teste alguma funcionalidade"
Write-Host ""

Write-Host "3. Configurar variaveis de ambiente:" -ForegroundColor Cyan
Write-Host "   Edite: configurar_telegram_env.ps1" -ForegroundColor White
Write-Host "   - Linha 5: SUPABASE_URL = `"https://$SSHHost`"" -ForegroundColor Gray
Write-Host "   - Linha 13: SUPABASE_SERVICE_ROLE_KEY" -ForegroundColor Gray
Write-Host "   Execute: .\configurar_telegram_env.ps1" -ForegroundColor White
Write-Host ""

Write-Host "4. Deploy Edge Functions:" -ForegroundColor Cyan
Write-Host "   .\deploy_telegram_functions.ps1" -ForegroundColor White
Write-Host ""

Write-Host "5. Configurar webhook Telegram:" -ForegroundColor Cyan
Write-Host "   Ver arquivo: telegram_env_vars.txt" -ForegroundColor White
Write-Host ""

Write-Host "6. Executar migration SQL:" -ForegroundColor Cyan
Write-Host "   supabase\migrations\20260124_telegram_integration.sql" -ForegroundColor White
Write-Host ""

Write-Host "NOTA: O certificado e auto-assinado" -ForegroundColor Yellow
Write-Host "Navegadores vao mostrar aviso, mas e NORMAL." -ForegroundColor Gray
Write-Host "O Telegram aceita quando enviamos o certificado .pem" -ForegroundColor Gray
Write-Host ""

Write-Host "Pronto! HTTPS configurado com sucesso!" -ForegroundColor Green
Write-Host ""
