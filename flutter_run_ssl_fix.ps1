# Script para executar flutter run resolvendo problema SSL do Gradle
# Solução: Usa variáveis de ambiente para desabilitar verificação SSL do Java

Write-Host "=== Executando Flutter com correção SSL do Gradle ===" -ForegroundColor Cyan
Write-Host ""

# Verificar se o Gradle já está baixado
$gradleZip = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.12-all\e26c64dba9e39dabf4767170f9689a6bb82e49096e073d59d1779e802d62c4d6\gradle-8.12-all.zip"
if (Test-Path $gradleZip) {
    Write-Host "✓ Gradle 8.12 já está baixado ($([math]::Round((Get-Item $gradleZip).Length / 1MB, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "⚠ Gradle ainda não foi baixado" -ForegroundColor Yellow
}

# Configurar variáveis de ambiente para desabilitar verificação SSL
# Usando abordagem que funciona com o Gradle Wrapper
$env:JAVA_OPTS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Dcom.sun.net.ssl.checkRevocation=false"
$env:GRADLE_OPTS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Dcom.sun.net.ssl.checkRevocation=false"

# Se ainda não funcionar, descomente para desabilitar completamente (APENAS DESENVOLVIMENTO):
# $env:JAVA_OPTS = "-Dtrust_all_cert=true"
# $env:GRADLE_OPTS = "-Dtrust_all_cert=true"

Write-Host "Variáveis de ambiente configuradas:" -ForegroundColor Yellow
Write-Host "  JAVA_OPTS = $env:JAVA_OPTS" -ForegroundColor Gray
Write-Host "  GRADLE_OPTS = $env:GRADLE_OPTS" -ForegroundColor Gray
Write-Host ""

# Executar flutter run
Write-Host "Executando flutter run..." -ForegroundColor Cyan
Write-Host ""
flutter run
