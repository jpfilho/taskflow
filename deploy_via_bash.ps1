# ============================================
# Deploy via Git Bash (usa o script bash original)
# ============================================
# Este script chama o deploy_agora.sh usando Git Bash

param(
    [switch]$NoBuild
)

Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY VIA BASH (IGUAL NO MAC)" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Verificar se Git Bash esta instalado
$gitBashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "C:\Git\bin\bash.exe"
)

$bashPath = $null
foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        $bashPath = $path
        break
    }
}

if (-not $bashPath) {
    Write-Host "ERRO: Git Bash nao encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Opcoes:" -ForegroundColor Yellow
    Write-Host "1. Instale o Git for Windows: https://git-scm.com/download/win" -ForegroundColor Cyan
    Write-Host "2. Ou use: .\deploy_completo.ps1" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "Git Bash encontrado: $bashPath" -ForegroundColor Green
Write-Host ""

# Converter caminho do Windows para formato Unix
$scriptPath = (Get-Location).Path.Replace('\', '/').Replace('C:', '/c')

# Executar o script bash
# MSYS_NO_PATHCONV=1 evita conversao automatica de paths no Git Bash
if ($NoBuild) {
    Write-Host "Executando deploy SEM BUILD..." -ForegroundColor Cyan
    Write-Host "(Voce digitara a senha APENAS UMA VEZ)" -ForegroundColor Yellow
    Write-Host ""
    & $bashPath -c "export MSYS_NO_PATHCONV=1 && cd '$scriptPath' && ./deploy_agora.sh --no-build"
} else {
    Write-Host "Executando deploy COMPLETO..." -ForegroundColor Cyan
    Write-Host "(Voce digitara a senha APENAS UMA VEZ)" -ForegroundColor Yellow
    Write-Host ""
    & $bashPath -c "export MSYS_NO_PATHCONV=1 && cd '$scriptPath' && ./deploy_agora.sh"
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "DEPLOY CONCLUIDO COM SUCESSO!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Acesse: http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "ERRO no deploy!" -ForegroundColor Red
    Write-Host ""
}
