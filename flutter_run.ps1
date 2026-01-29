# Wrapper script para flutter run com SSL desabilitado
# Use este script em vez de executar 'flutter run' diretamente

# Configurar variaveis de ambiente para desabilitar SSL
$env:JAVA_OPTS = "-Djavax.net.ssl.trustStore=NONE -Djavax.net.ssl.trustStoreType=Windows-ROOT"
$env:GRADLE_OPTS = "-Djavax.net.ssl.trustStore=NONE -Djavax.net.ssl.trustStoreType=Windows-ROOT"

Write-Host "Variaveis SSL configuradas. Executando flutter run..." -ForegroundColor Cyan

# Executar flutter run com todos os argumentos passados
flutter run @args
