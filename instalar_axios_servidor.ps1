# Script para instalar o módulo axios no servidor via SSH

$SERVER = "root@212.85.0.249"
$PROJECT_DIR = "/root/telegram-webhook"

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Instalando axios no servidor" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Servidor: $SERVER" -ForegroundColor Yellow
Write-Host "Diretório: $PROJECT_DIR" -ForegroundColor Yellow
Write-Host ""

Write-Host "Executando: npm install axios" -ForegroundColor Yellow
Write-Host ""

# Executar o comando npm install axios via SSH
ssh $SERVER "cd $PROJECT_DIR && npm install axios"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Erro ao instalar axios!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ axios instalado com sucesso!" -ForegroundColor Green
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Concluído!" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
