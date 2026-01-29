# Script para configurar SSL do Gradle permanentemente

Write-Host "=== Configurando SSL do Gradle permanentemente ===" -ForegroundColor Cyan

# Configurar variaveis de ambiente do usuario
$javaOpts = "-Djavax.net.ssl.trustStore=NONE -Djavax.net.ssl.trustStoreType=Windows-ROOT"
$gradleOpts = "-Djavax.net.ssl.trustStore=NONE -Djavax.net.ssl.trustStoreType=Windows-ROOT"

[System.Environment]::SetEnvironmentVariable('JAVA_OPTS', $javaOpts, 'User')
[System.Environment]::SetEnvironmentVariable('GRADLE_OPTS', $gradleOpts, 'User')

Write-Host "`nVariaveis configuradas:" -ForegroundColor Green
Write-Host "  JAVA_OPTS = $javaOpts" -ForegroundColor Yellow
Write-Host "  GRADLE_OPTS = $gradleOpts" -ForegroundColor Yellow

Write-Host "`nIMPORTANTE:" -ForegroundColor Yellow
Write-Host "1. Feche e reabra o terminal" -ForegroundColor White
Write-Host "2. Execute: flutter run" -ForegroundColor White
Write-Host "`nAs variaveis serao carregadas automaticamente." -ForegroundColor Cyan

Write-Host "`n=== Configuracao concluida! ===" -ForegroundColor Green
