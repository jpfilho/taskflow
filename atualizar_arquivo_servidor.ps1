# Script para atualizar o arquivo no servidor e corrigir o service

$SERVER = "root@212.85.0.249"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "ATUALIZAR ARQUIVO NO SERVIDOR" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$arquivoLocal = "telegram-webhook-server-generalized.js"

if (-not (Test-Path $arquivoLocal)) {
    Write-Host "Arquivo nao encontrado: $arquivoLocal" -ForegroundColor Red
    exit 1
}

Write-Host "Copiando arquivo atualizado para o servidor..." -ForegroundColor Yellow
scp $arquivoLocal "${SERVER}:/root/telegram-webhook/telegram-webhook-server-generalized.js"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao copiar arquivo!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Arquivo copiado com sucesso!" -ForegroundColor Green
Write-Host ""
Write-Host "Agora execute: .\corrigir_arquivo_servico.ps1" -ForegroundColor Yellow
Write-Host "para atualizar o systemd service" -ForegroundColor Yellow
Write-Host ""
