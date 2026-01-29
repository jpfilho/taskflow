# ============================================
# Deploy COMPLETO - Build + Transferir
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY COMPLETO (BUILD + TRANSFERIR)" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# PASSO 1: FAZER BUILD
Write-Host "1. FAZENDO BUILD DA APLICACAO..." -ForegroundColor Cyan
Write-Host "   (Isso vai demorar 3-5 minutos)" -ForegroundColor Gray
Write-Host ""

Write-Host "   Limpando build anterior..." -ForegroundColor Gray
flutter clean

Write-Host "   Baixando dependencias..." -ForegroundColor Gray
flutter pub get

Write-Host "   Compilando para web..." -ForegroundColor Gray
flutter build web --release --base-href="/task2026/"

if (-not (Test-Path "build\web")) {
    Write-Host ""
    Write-Host "ERRO: Build falhou!" -ForegroundColor Red
    Write-Host "Verifique os erros acima e tente novamente." -ForegroundColor Yellow
    exit 1
}

Write-Host "   BUILD CONCLUIDO!" -ForegroundColor Green
Write-Host ""

# PASSO 2: PREPARAR ARQUIVOS
Write-Host "2. PREPARANDO ARQUIVOS..." -ForegroundColor Cyan

$BUILD_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BUILD_TIMESTAMP | Out-File -FilePath "build\web\version.txt" -NoNewline -Encoding UTF8

# Cache-busting
$indexPath = "build\web\index.html"
if (Test-Path $indexPath) {
    $content = Get-Content $indexPath -Raw
    $content = $content -replace 'main\.dart\.js', "main.dart.js?v=$BUILD_TIMESTAMP"
    $content | Out-File -FilePath $indexPath -NoNewline -Encoding UTF8
}

$size = (Get-ChildItem -Path "build\web" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "   Tamanho: $([math]::Round($size, 2)) MB" -ForegroundColor Gray
Write-Host "   Versao: $BUILD_TIMESTAMP" -ForegroundColor Gray
Write-Host ""

# PASSO 3: TRANSFERIR
Write-Host "3. TRANSFERINDO PARA SERVIDOR..." -ForegroundColor Cyan
Write-Host "   (Voce precisara digitar a senha 4 vezes)" -ForegroundColor Yellow
Write-Host ""

Write-Host "   Criando diretorio..." -ForegroundColor Gray
ssh $SERVER "mkdir -p $REMOTE_PATH"

Write-Host "   Limpando conteudo antigo..." -ForegroundColor Gray
ssh $SERVER "rm -rf $REMOTE_PATH/*"

Write-Host "   Transferindo arquivos..." -ForegroundColor Gray
Write-Host "   (Isso pode demorar 1-2 minutos)" -ForegroundColor Gray
scp -r build\web\* "${SERVER}:${REMOTE_PATH}/"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERRO ao transferir!" -ForegroundColor Red
    exit 1
}

Write-Host "   Ajustando permissoes..." -ForegroundColor Gray
ssh $SERVER "sudo chown -R www-data:www-data $REMOTE_PATH"
ssh $SERVER "sudo chmod -R 755 $REMOTE_PATH"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUIDO COM SUCESSO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "A aplicacao esta disponivel em:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
Write-Host "   http://taskflowv3.com.br/" -ForegroundColor Yellow
Write-Host ""
Write-Host "Versao do build: $BUILD_TIMESTAMP" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANTE: Pressione Ctrl+Shift+R no navegador" -ForegroundColor Yellow
Write-Host "para forcar a atualizacao e ver as mudancas!" -ForegroundColor Yellow
Write-Host ""
