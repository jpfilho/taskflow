# Script para criar estrutura do Gradle manualmente com hash correto

Write-Host "=== Criando estrutura do Gradle manualmente ===" -ForegroundColor Cyan

$gradleVersion = "8.12"
$gradleUrl = "https://services.gradle.org/distributions/gradle-${gradleVersion}-all.zip"
$basePath = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-${gradleVersion}-all"
$zipFile = "$basePath\gradle-${gradleVersion}-all.zip"

# Calcular hash SHA256 da URL (o Gradle usa isso para criar a pasta)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$urlBytes = [System.Text.Encoding]::UTF8.GetBytes($gradleUrl)
$hashBytes = $sha256.ComputeHash($urlBytes)
$hashString = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()

Write-Host "URL: $gradleUrl" -ForegroundColor Yellow
Write-Host "Hash calculado: $hashString" -ForegroundColor Yellow

# Criar estrutura de pastas
$targetFolder = "$basePath\$hashString"
Write-Host "`nCriando pasta: $targetFolder" -ForegroundColor Cyan

if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    Write-Host "Pasta criada!" -ForegroundColor Green
} else {
    Write-Host "Pasta ja existe!" -ForegroundColor Green
}

# Mover arquivo ZIP se existir na raiz
if (Test-Path $zipFile) {
    $targetZip = "$targetFolder\gradle-${gradleVersion}-all.zip"
    
    if (Test-Path $targetZip) {
        Write-Host "`nArquivo ja existe no destino. Removendo da origem..." -ForegroundColor Yellow
        Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
        Write-Host "Limpeza concluida!" -ForegroundColor Green
    } else {
        Write-Host "`nMovendo arquivo para pasta com hash..." -ForegroundColor Cyan
        Move-Item -Path $zipFile -Destination $targetZip -Force
        Write-Host "Arquivo movido com sucesso!" -ForegroundColor Green
        Write-Host "Destino: $targetZip" -ForegroundColor Cyan
    }
} else {
    Write-Host "`nArquivo ZIP nao encontrado na origem: $zipFile" -ForegroundColor Red
    Write-Host "Execute primeiro: baixar_gradle_manual.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== Estrutura criada com sucesso! ===" -ForegroundColor Green
Write-Host "`nAgora execute: flutter run" -ForegroundColor Yellow
