# Script para executar flutter run com SSL desabilitado para o Gradle
# Solução para erro: PKIX path building failed

Write-Host "Executando flutter run com SSL desabilitado para Gradle..." -ForegroundColor Cyan

# Desabilitar verificacao SSL usando truststore vazio (mais seguro que desabilitar completamente)
# Isso permite que o Java use o truststore padrão do Windows
$env:JAVA_OPTS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT"
$env:GRADLE_OPTS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT"

# Alternativa: Se ainda não funcionar, desabilitar verificação SSL completamente (apenas desenvolvimento)
# Descomente as linhas abaixo se a solução acima não funcionar:
# $env:JAVA_OPTS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Dcom.sun.net.ssl.checkRevocation=false"
# $env:GRADLE_OPTS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Dcom.sun.net.ssl.checkRevocation=false"

# Executar flutter run
flutter run
