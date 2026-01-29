# Script para mover Gradle para a pasta com hash criada pelo Gradle

$gradleVersion = "8.12"
$basePath = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-${gradleVersion}-all"
$zipFile = "$basePath\gradle-${gradleVersion}-all.zip"

if (-not (Test-Path $zipFile)) {
    Write-Host "Arquivo ZIP nao encontrado: $zipFile" -ForegroundColor Red
    exit 1
}

Write-Host "Procurando pasta com hash..." -ForegroundColor Cyan

# Procurar por pastas com hash (geralmente uma string alfanumerica longa)
$hashFolders = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^[a-f0-9]+$' }

if ($hashFolders.Count -eq 0) {
    Write-Host "Nenhuma pasta com hash encontrada ainda." -ForegroundColor Yellow
    Write-Host "O Gradle vai criar a pasta quando tentar baixar." -ForegroundColor Yellow
    Write-Host "Execute 'flutter run' e depois execute este script novamente." -ForegroundColor Yellow
    exit 0
}

if ($hashFolders.Count -gt 1) {
    Write-Host "Multiplas pastas com hash encontradas. Usando a primeira." -ForegroundColor Yellow
}

$targetFolder = $hashFolders[0].FullName
$targetZip = "$targetFolder\gradle-${gradleVersion}-all.zip"

if (Test-Path $targetZip) {
    Write-Host "Arquivo ja existe no destino: $targetZip" -ForegroundColor Green
    Write-Host "Removendo arquivo da origem..." -ForegroundColor Cyan
    Remove-Item $zipFile -Force
    Write-Host "Concluido!" -ForegroundColor Green
} else {
    Write-Host "Movendo arquivo para: $targetFolder" -ForegroundColor Cyan
    Move-Item -Path $zipFile -Destination $targetZip -Force
    Write-Host "Arquivo movido com sucesso!" -ForegroundColor Green
}

Write-Host "`nAgora execute: flutter run" -ForegroundColor Yellow
