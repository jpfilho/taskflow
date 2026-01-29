# ============================================
# Subir nova versao do projeto para o Git
# ============================================
# Execute no PowerShell: .\subir_versao_git.ps1
# Ou com mensagem: .\subir_versao_git.ps1 -Mensagem "Minha mensagem"

param(
    [string]$Mensagem = "Nova versao do projeto"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " SUBIR VERSAO PARA O GIT" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# 1. Status
Write-Host "1. Verificando alteracoes..." -ForegroundColor Cyan
$status = git status --short
if (-not $status) {
    Write-Host "   Nenhuma alteracao para enviar." -ForegroundColor Yellow
    exit 0
}
Write-Host "   Alteracoes encontradas." -ForegroundColor Green
Write-Host ""

# 2. Add tudo
Write-Host "2. Adicionando arquivos (git add -A)..." -ForegroundColor Cyan
git add -A
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ERRO ao adicionar arquivos." -ForegroundColor Red
    exit 1
}
Write-Host "   OK." -ForegroundColor Green
Write-Host ""

# 3. Commit
Write-Host "3. Fazendo commit..." -ForegroundColor Cyan
Write-Host "   Mensagem: $Mensagem" -ForegroundColor Gray
git commit -m $Mensagem
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ERRO no commit (pode ser que nao haja nada novo apos o add)." -ForegroundColor Red
    exit 1
}
Write-Host "   OK." -ForegroundColor Green
Write-Host ""

# 4. Push
Write-Host "4. Enviando para o remoto (git push origin main)..." -ForegroundColor Cyan
git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ERRO no push. Verifique usuario/senha ou chave SSH." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " VERSAO ENVIADA COM SUCESSO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
