# Script para configurar SSL do Gradle permanentemente
# Resolve o erro: PKIX path building failed

Write-Host "=== Configurando SSL do Gradle permanentemente ===" -ForegroundColor Cyan
Write-Host ""

# Configurar variáveis de ambiente do usuário
$javaOpts = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Dcom.sun.net.ssl.checkRevocation=false"
$gradleOpts = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Dcom.sun.net.ssl.checkRevocation=false"

[System.Environment]::SetEnvironmentVariable('JAVA_OPTS', $javaOpts, 'User')
[System.Environment]::SetEnvironmentVariable('GRADLE_OPTS', $gradleOpts, 'User')

Write-Host "✅ Variáveis configuradas:" -ForegroundColor Green
Write-Host "  JAVA_OPTS = $javaOpts" -ForegroundColor Yellow
Write-Host "  GRADLE_OPTS = $gradleOpts" -ForegroundColor Yellow
Write-Host ""

Write-Host "⚠️ IMPORTANTE:" -ForegroundColor Yellow
Write-Host "1. Feche completamente este terminal" -ForegroundColor White
Write-Host "2. Abra um novo terminal/PowerShell" -ForegroundColor White
Write-Host "3. Execute: flutter run" -ForegroundColor White
Write-Host ""

Write-Host "As variáveis serão carregadas automaticamente em novos terminais." -ForegroundColor Cyan
Write-Host ""

Write-Host "=== Configuração concluída! ===" -ForegroundColor Green
