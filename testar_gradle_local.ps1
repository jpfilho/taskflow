# Script para testar se Gradle encontra arquivo local

Write-Host "=== Testando se Gradle encontra arquivo local ===" -ForegroundColor Cyan

$hashFolder = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.12-all\e26c64dba9e39dabf4767170f9689a6bb82e49096e073d59d1779e802d62c4d6"
$zipFile = "$hashFolder\gradle-8.12-all.zip"
$okFile = "$hashFolder\gradle-8.12-all.zip.ok"

Write-Host "`nVerificando arquivos:" -ForegroundColor Yellow
Write-Host "  ZIP: $(if (Test-Path $zipFile) { 'OK - ' + [math]::Round((Get-Item $zipFile).Length / 1MB, 2) + ' MB' } else { 'FALTANDO' })"
Write-Host "  OK:  $(if (Test-Path $okFile) { 'OK' } else { 'FALTANDO' })"

if (-not (Test-Path $okFile)) {
    Write-Host "`nCriando arquivo .ok..." -ForegroundColor Cyan
    "" | Out-File -FilePath $okFile -Encoding ASCII
    Write-Host "Arquivo .ok criado!" -ForegroundColor Green
}

# Verificar se Gradle ja foi extraido
$extractedFolder = "$hashFolder\gradle-8.12"
if (Test-Path $extractedFolder) {
    Write-Host "`nGradle ja foi extraido em: $extractedFolder" -ForegroundColor Green
    $binGradle = "$extractedFolder\bin\gradle.bat"
    if (Test-Path $binGradle) {
        Write-Host "Gradle executavel encontrado!" -ForegroundColor Green
    }
} else {
    Write-Host "`nGradle ainda nao foi extraido." -ForegroundColor Yellow
    Write-Host "O Gradle vai extrair automaticamente quando executar flutter run." -ForegroundColor Cyan
}

Write-Host "`n=== Teste concluido ===" -ForegroundColor Green
Write-Host "`nExecute: flutter run" -ForegroundColor Yellow
Write-Host "Ou use: powershell -ExecutionPolicy Bypass -File flutter_run.ps1" -ForegroundColor Yellow
