# ============================================
# Deploy RAPIDO - Versao Otimizada
# ============================================

param(
    [switch]$NoBuild
)

$SERVER = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY RAPIDO" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Build se necessario
if (-not $NoBuild) {
    Write-Host "1. Fazendo build..." -ForegroundColor Cyan
    flutter clean | Out-Null
    flutter pub get | Out-Null
    flutter build web --release --base-href="/task2026/"
    
    if (-not (Test-Path "build\web")) {
        Write-Host "ERRO: Build falhou!" -ForegroundColor Red
        exit 1
    }
    Write-Host "   OK!" -ForegroundColor Green
} else {
    Write-Host "1. Pulando build (usando existente)..." -ForegroundColor Yellow
}

# Versao
$BUILD_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BUILD_TIMESTAMP | Out-File -FilePath "build\web\version.txt" -NoNewline -Encoding UTF8
Write-Host ""
Write-Host "2. Versao: $BUILD_TIMESTAMP" -ForegroundColor Cyan

# Cache-busting basico
$indexPath = "build\web\index.html"
if (Test-Path $indexPath) {
    $content = Get-Content $indexPath -Raw
    $content = $content -replace 'main\.dart\.js', "main.dart.js?v=$BUILD_TIMESTAMP"
    $content | Out-File -FilePath $indexPath -NoNewline -Encoding UTF8
}

# Transferir arquivos (SEM backup, SEM verificacoes extras)
Write-Host ""
Write-Host "3. Transferindo arquivos..." -ForegroundColor Cyan
Write-Host "   Aguarde..." -ForegroundColor Gray

# Criar diretorio e limpar (comandos separados evitam problema de line endings)
ssh $SERVER "mkdir -p $REMOTE_PATH"
ssh $SERVER "rm -rf $REMOTE_PATH/*"

# SCP direto
scp -r -q build\web\* "${SERVER}:${REMOTE_PATH}/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ERRO ao transferir!" -ForegroundColor Red
    exit 1
}

Write-Host "   OK!" -ForegroundColor Green

# Ajustar permissoes
Write-Host ""
Write-Host "4. Ajustando permissoes..." -ForegroundColor Cyan
ssh $SERVER "sudo chown -R www-data:www-data $REMOTE_PATH"
ssh $SERVER "sudo chmod -R 755 $REMOTE_PATH"
Write-Host "   OK!" -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Acesse: http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
Write-Host ""
Write-Host "Versao: $BUILD_TIMESTAMP" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pressione Ctrl+Shift+R no navegador para atualizar" -ForegroundColor Gray
Write-Host ""
