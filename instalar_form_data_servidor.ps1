# Script para instalar o módulo form-data no servidor via SSH

$SERVER = "root@212.85.0.249"
$PROJECT_DIR = "/root/telegram-webhook"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Instalando form-data no servidor" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Servidor: $SERVER" -ForegroundColor Yellow
Write-Host "Diretório: $PROJECT_DIR" -ForegroundColor Yellow
Write-Host ""

# Comando SSH para instalar form-data
$sshCommand = "cd $PROJECT_DIR && npm install form-data"

Write-Host "Executando: npm install form-data" -ForegroundColor Green
Write-Host ""

try {
    ssh $SERVER $sshCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ form-data instalado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "❌ Erro ao instalar form-data (código: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "❌ Erro ao executar SSH: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Concluído!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
