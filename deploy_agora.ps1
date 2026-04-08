# ============================================
# Script de Deploy Rapido - Windows PowerShell
# ============================================
# Usa ssh/scp nativos do Windows (sem Posh-SSH)
# Voce sera solicitado a digitar a senha SSH
# (maximo 2 vezes: 1x scp + 1x ssh)

param(
    [switch]$NoBuild
)

# Configuracoes do servidor
$SSH_USER = "root"
$SSH_HOST = "212.85.0.249"
$SSH_PORT = 22
$REMOTE_PATH = "/var/www/html/task2026"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deploy da Aplicacao para Producao" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Servidor: ${SSH_USER}@${SSH_HOST}" -ForegroundColor Cyan
Write-Host "Caminho remoto: $REMOTE_PATH" -ForegroundColor Cyan
Write-Host ""

# Verificar se ssh e scp estao disponiveis
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: Comando 'ssh' nao encontrado!" -ForegroundColor Red
    Write-Host "   Instale o OpenSSH Client nas Configuracoes do Windows" -ForegroundColor Yellow
    exit 1
}
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: Comando 'scp' nao encontrado!" -ForegroundColor Red
    exit 1
}

# Verificar se deve fazer build
if ($NoBuild) {
    Write-Host "AVISO: Pulando build (usando build existente)" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "Fazendo build da aplicacao..." -ForegroundColor Cyan
    Write-Host ""

    # Limpar build anterior
    Write-Host "   Limpando build anterior..." -ForegroundColor Gray
    flutter clean | Out-Null

    # Obter dependencias
    Write-Host "   Obtendo dependencias..." -ForegroundColor Gray
    flutter pub get | Out-Null

    # Build para web
    Write-Host "   Compilando para web (release)..." -ForegroundColor Gray
    flutter build web --release --base-href="/task2026/"

    if (-not (Test-Path "build\web")) {
        Write-Host "ERRO: Build falhou! Diretorio build/web nao encontrado!" -ForegroundColor Red
        exit 1
    }

    Write-Host "   Build concluido!" -ForegroundColor Green
    Write-Host ""
}

# Verificar se build/web existe
if (-not (Test-Path "build\web")) {
    Write-Host "ERRO: Diretorio build/web nao encontrado!" -ForegroundColor Red
    Write-Host "   Execute primeiro: flutter build web --release" -ForegroundColor Yellow
    exit 1
}

# Criar arquivo de versao com timestamp
$BUILD_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$VERSION_FILE = "build\web\version.txt"
$BUILD_TIMESTAMP | Out-File -FilePath $VERSION_FILE -NoNewline -Encoding UTF8
Write-Host "Versao do build: $BUILD_TIMESTAMP" -ForegroundColor Cyan

# Aplicar cache-busting no index.html
Write-Host "Aplicando cache-busting em index.html..." -ForegroundColor Cyan
$indexPath = "build\web\index.html"
if (Test-Path $indexPath) {
    $content = Get-Content $indexPath -Raw
    $content = $content -replace 'main\.dart\.js', "main.dart.js?v=$BUILD_TIMESTAMP"
    $content = $content -replace 'flutter\.js', "flutter.js?v=$BUILD_TIMESTAMP"
    $content = $content -replace 'canvaskit\.wasm', "canvaskit.wasm?v=$BUILD_TIMESTAMP"
    $content = $content -replace 'flutter_service_worker\.js', "flutter_service_worker.js?v=$BUILD_TIMESTAMP"
    $content | Out-File -FilePath $indexPath -NoNewline -Encoding UTF8
}

# Desabilitar service worker para evitar cache agressivo
$flutterJsPath = "build\web\flutter.js"
if (Test-Path $flutterJsPath) {
    Write-Host "Desabilitando service worker..." -ForegroundColor Cyan
    $content = Get-Content $flutterJsPath -Raw
    $content = $content -replace 'navigator\.serviceWorker\.register\([^;]*;', ''
    $content | Out-File -FilePath $flutterJsPath -NoNewline -Encoding UTF8
}

# Remover service worker gerado
$swPath = "build\web\flutter_service_worker.js"
if (Test-Path $swPath) {
    "// Service worker desabilitado no deploy" | Out-File -FilePath $swPath -NoNewline -Encoding UTF8
}

# Criar regras de cache (.htaccess)
$htaccessContent = @"
# Forcar nao-cache para HTML e service worker
<FilesMatch "^(index\.html|flutter_service_worker\.js|version\.txt)$">
  Header set Cache-Control "no-store, no-cache, must-revalidate, max-age=0"
</FilesMatch>

# Ativos estaticos podem usar cache longo
<FilesMatch "\.(js|css|json|wasm|png|jpg|jpeg|gif|svg|ico)$">
  Header set Cache-Control "public, max-age=31536000, immutable"
</FilesMatch>
"@
$htaccessContent | Out-File -FilePath "build\web\.htaccess" -NoNewline -Encoding UTF8

Write-Host ""
$size = (Get-ChildItem -Path "build\web" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "Arquivos para deploy: $([math]::Round($size, 2)) MB" -ForegroundColor Cyan
Write-Host ""

# ---- Empacotar em .tar.gz para transferencia rapida ----
$archiveName = "task2026_web_$BUILD_TIMESTAMP.tar.gz"
$archivePath = Join-Path $PWD $archiveName

Write-Host "Empacotando arquivos..." -ForegroundColor Cyan
tar -czf "$archivePath" -C build\web .
if (-not (Test-Path $archivePath)) {
    Write-Host "ERRO: Falha ao criar pacote $archiveName" -ForegroundColor Red
    exit 1
}
$pkgSize = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
Write-Host "   Pacote: $archiveName ($pkgSize MB)" -ForegroundColor Gray
Write-Host ""

# ---- Transferir via SCP (1 prompt de senha) ----
Write-Host "Transferindo pacote para o servidor..." -ForegroundColor Cyan
Write-Host "   (Digite a senha SSH quando solicitado)" -ForegroundColor Yellow
Write-Host ""
scp -o PubkeyAuthentication=no -o IPQoS=none -o KexAlgorithms=curve25519-sha256@libssh.org -P $SSH_PORT "$archivePath" "${SSH_USER}@${SSH_HOST}:/tmp/$archiveName"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Falha ao transferir o pacote via rede!" -ForegroundColor Red
    Write-Host "O pacote foi MANTIDO em: $archivePath" -ForegroundColor Yellow
    Write-Host "Voce pode fazer o upload manual pelo painel da Hostinger!" -ForegroundColor Yellow
    exit 1
}

Write-Host "   Transferencia concluida!" -ForegroundColor Green
Write-Host ""

# ---- Executar comandos remotos (1 prompt de senha) ----
Write-Host "Extraindo e configurando no servidor..." -ForegroundColor Cyan
Write-Host "   (Digite a senha SSH novamente)" -ForegroundColor Yellow
Write-Host ""

# Comando composto: backup + limpar + extrair + permissoes + limpar pacote
$remoteCmd = @"
set -e
echo '   Fazendo backup...'
if [ -d '$REMOTE_PATH' ] && [ -f '$REMOTE_PATH/index.html' ]; then
  cp -r '$REMOTE_PATH' '${REMOTE_PATH}_backup_$BUILD_TIMESTAMP' 2>/dev/null || true
fi
echo '   Limpando destino...'
mkdir -p '$REMOTE_PATH'
rm -rf $REMOTE_PATH/*
echo '   Extraindo pacote...'
tar -xzf '/tmp/$archiveName' -C '$REMOTE_PATH'
echo '   Ajustando permissoes...'
chown -R www-data:www-data '$REMOTE_PATH'
chmod -R 755 '$REMOTE_PATH'
echo '   Limpando pacote temporario...'
rm -f '/tmp/$archiveName'
echo '   Verificando versao...'
cat '$REMOTE_PATH/version.txt' 2>/dev/null || echo 'N/A'
"@

$result = ssh -o PubkeyAuthentication=no -o IPQoS=none -o KexAlgorithms=curve25519-sha256@libssh.org -p $SSH_PORT "${SSH_USER}@${SSH_HOST}" $remoteCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "AVISO: Alguns comandos remotos podem ter falhado" -ForegroundColor Yellow
}

# Verificar versao
$remoteVersion = ($result | Select-Object -Last 1).Trim()
if ($remoteVersion -eq $BUILD_TIMESTAMP) {
    Write-Host "   Versao confirmada no servidor: $remoteVersion" -ForegroundColor Green
} else {
    Write-Host "   Versao no servidor: $remoteVersion (esperado: $BUILD_TIMESTAMP)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deploy concluido!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Acesse a aplicacao em:" -ForegroundColor Cyan
Write-Host "   http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
Write-Host "   ou" -ForegroundColor Gray
Write-Host "   http://taskflowv3.com.br/" -ForegroundColor Yellow
Write-Host ""
Write-Host "Dica: Se a versao nao atualizou no navegador:" -ForegroundColor Cyan
Write-Host "   - Pressione Ctrl+Shift+R para forcar atualizacao" -ForegroundColor Gray
Write-Host "   - Ou limpe o cache do navegador" -ForegroundColor Gray
Write-Host ""
Write-Host "Versao do build: $BUILD_TIMESTAMP" -ForegroundColor Cyan
Write-Host ""
