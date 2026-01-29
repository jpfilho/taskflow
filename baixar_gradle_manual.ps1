# Script para baixar Gradle manualmente e resolver erro SSL

Write-Host "Baixando Gradle 8.12 manualmente..." -ForegroundColor Cyan

$gradleVersion = "8.12"
$gradleUrl = "https://services.gradle.org/distributions/gradle-${gradleVersion}-all.zip"
$userProfile = $env:USERPROFILE
$gradleWrapperPath = "$userProfile\.gradle\wrapper\dists\gradle-${gradleVersion}-all"

Write-Host "URL: $gradleUrl" -ForegroundColor Yellow
Write-Host "Destino: $gradleWrapperPath" -ForegroundColor Yellow

# Criar diretorio se nao existir
if (-not (Test-Path $gradleWrapperPath)) {
    New-Item -ItemType Directory -Path $gradleWrapperPath -Force | Out-Null
    Write-Host "Diretorio criado: $gradleWrapperPath" -ForegroundColor Green
}

# Tentar baixar usando diferentes metodos
$downloaded = $false
$zipPath = "$gradleWrapperPath\gradle-${gradleVersion}-all.zip"

# Metodo 1: Invoke-WebRequest com bypass SSL (temporario)
try {
    Write-Host "`nTentando baixar com Invoke-WebRequest..." -ForegroundColor Cyan
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    Invoke-WebRequest -Uri $gradleUrl -OutFile $zipPath -UseBasicParsing
    $downloaded = $true
    Write-Host "Download concluido!" -ForegroundColor Green
} catch {
    Write-Host "Erro com Invoke-WebRequest: $($_.Exception.Message)" -ForegroundColor Red
}

# Metodo 2: Usar curl se disponivel
if (-not $downloaded) {
    try {
        Write-Host "`nTentando baixar com curl..." -ForegroundColor Cyan
        curl.exe -L -k -o $zipPath $gradleUrl
        if (Test-Path $zipPath) {
            $downloaded = $true
            Write-Host "Download concluido com curl!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Erro com curl: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($downloaded) {
    Write-Host "`nGradle baixado com sucesso!" -ForegroundColor Green
    Write-Host "Local: $zipPath" -ForegroundColor Cyan
    Write-Host "`nProximos passos:" -ForegroundColor Yellow
    Write-Host "1. Execute: flutter clean" -ForegroundColor White
    Write-Host "2. Execute: flutter pub get" -ForegroundColor White
    Write-Host "3. Execute: flutter run" -ForegroundColor White
    Write-Host "`nO Gradle vai extrair automaticamente o arquivo ZIP." -ForegroundColor Cyan
} else {
    Write-Host "`nNao foi possivel baixar automaticamente." -ForegroundColor Red
    Write-Host "`nSolucao manual:" -ForegroundColor Yellow
    Write-Host "1. Abra no navegador: $gradleUrl" -ForegroundColor White
    Write-Host "2. Baixe o arquivo ZIP" -ForegroundColor White
    Write-Host "3. Copie para: $gradleWrapperPath" -ForegroundColor White
    Write-Host "4. Renomeie para: gradle-${gradleVersion}-all.zip" -ForegroundColor White
    Write-Host "`nO Gradle vai extrair automaticamente na proxima execucao." -ForegroundColor Cyan
}
