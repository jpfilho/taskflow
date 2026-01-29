# ============================================
# Deploy - SOMENTE TRANSFERIR ARQUIVOS
# ============================================
# NAO FAZ BUILD - apenas transfere build/web/ existente

$SERVER = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "TRANSFERINDO ARQUIVOS (SEM BUILD)" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Verificar se build/web existe
if (-not (Test-Path "build\web")) {
    Write-Host "ERRO: Diretorio build/web nao encontrado!" -ForegroundColor Red
    Write-Host "Execute primeiro: flutter build web --release --base-href='/task2026/'" -ForegroundColor Yellow
    exit 1
}

# Criar versao
$BUILD_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BUILD_TIMESTAMP | Out-File -FilePath "build\web\version.txt" -NoNewline -Encoding UTF8
Write-Host "Versao: $BUILD_TIMESTAMP" -ForegroundColor Cyan
Write-Host ""

# 1. Criar diretorio
Write-Host "1. Criando diretorio no servidor..." -ForegroundColor Cyan
ssh $SERVER "mkdir -p $REMOTE_PATH"

# 2. Limpar conteudo antigo
Write-Host "2. Limpando conteudo antigo..." -ForegroundColor Cyan
ssh $SERVER "rm -rf $REMOTE_PATH/*"

# 3. Transferir arquivos
Write-Host "3. Transferindo arquivos (isso pode demorar)..." -ForegroundColor Cyan
scp -r build\web\* "${SERVER}:${REMOTE_PATH}/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO ao transferir!" -ForegroundColor Red
    exit 1
}

# 4. Ajustar permissoes
Write-Host "4. Ajustando permissoes..." -ForegroundColor Cyan
ssh $SERVER "sudo chown -R www-data:www-data $REMOTE_PATH"
ssh $SERVER "sudo chmod -R 755 $REMOTE_PATH"

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
