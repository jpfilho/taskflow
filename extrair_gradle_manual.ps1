# Script para extrair Gradle manualmente (pode demorar alguns minutos)

Write-Host "=== Extraindo Gradle manualmente ===" -ForegroundColor Cyan
Write-Host "Isso pode demorar alguns minutos (219 MB)..." -ForegroundColor Yellow

$hashFolder = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.12-all\e26c64dba9e39dabf4767170f9689a6bb82e49096e073d59d1779e802d62c4d6"
$zipFile = "$hashFolder\gradle-8.12-all.zip"
$extractTo = "$hashFolder"

if (-not (Test-Path $zipFile)) {
    Write-Host "Arquivo ZIP nao encontrado: $zipFile" -ForegroundColor Red
    exit 1
}

$extractedFolder = "$extractTo\gradle-8.12"
if (Test-Path $extractedFolder) {
    Write-Host "Gradle ja foi extraido em: $extractedFolder" -ForegroundColor Green
    exit 0
}

Write-Host "`nExtraindo..." -ForegroundColor Cyan
try {
    Expand-Archive -Path $zipFile -DestinationPath $extractTo -Force
    Write-Host "`nGradle extraido com sucesso!" -ForegroundColor Green
    Write-Host "Local: $extractedFolder" -ForegroundColor Cyan
    
    $binGradle = "$extractedFolder\bin\gradle.bat"
    if (Test-Path $binGradle) {
        Write-Host "Gradle executavel encontrado!" -ForegroundColor Green
    }
    
    Write-Host "`nAgora execute: flutter run" -ForegroundColor Yellow
} catch {
    Write-Host "`nErro ao extrair: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
