# ============================================
# DEPLOY CORRETO - Replica deploy_agora.sh
# ============================================

param(
    [switch]$SkipBuild
)

$SERVER = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY TASKFLOW WEB" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# PASSO 1: BUILD
if (-not $SkipBuild) {
    Write-Host "1. FAZENDO BUILD..." -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "   Limpando..." -ForegroundColor Gray
    flutter clean
    
    Write-Host ""
    Write-Host "   Obtendo dependencias..." -ForegroundColor Gray
    flutter pub get
    
    Write-Host ""
    Write-Host "   Compilando (aguarde)..." -ForegroundColor Gray
    flutter build web --release --base-href="/task2026/"
    
    if (-not (Test-Path "build\web\index.html")) {
        Write-Host ""
        Write-Host "ERRO: Build falhou - index.html nao encontrado!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "   Build concluido!" -ForegroundColor Green
} else {
    Write-Host "1. Pulando build (usando build existente)..." -ForegroundColor Yellow
    if (-not (Test-Path "build\web\index.html")) {
        Write-Host ""
        Write-Host "ERRO: build/web nao encontrado!" -ForegroundColor Red
        Write-Host "Execute sem -SkipBuild primeiro!" -ForegroundColor Red
        exit 1
    }
}

# PASSO 2: PREPARAR ARQUIVOS
Write-Host ""
Write-Host "2. PREPARANDO ARQUIVOS..." -ForegroundColor Cyan

$BUILD_TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BUILD_TIMESTAMP | Out-File -FilePath "build\web\version.txt" -NoNewline -Encoding UTF8

# Cache-busting no index.html
$indexPath = "build\web\index.html"
if (Test-Path $indexPath) {
    $content = Get-Content $indexPath -Raw
    $content = $content -replace 'main\.dart\.js', "main.dart.js?v=$BUILD_TIMESTAMP"
    $content | Out-File -FilePath $indexPath -NoNewline -Encoding UTF8
    Write-Host "   Cache-busting aplicado: ?v=$BUILD_TIMESTAMP" -ForegroundColor Gray
}

$fileCount = (Get-ChildItem -Path "build\web" -Recurse -File).Count
$size = (Get-ChildItem -Path "build\web" -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "   Arquivos: $fileCount" -ForegroundColor Gray
Write-Host "   Tamanho total: $([math]::Round($size, 2)) MB" -ForegroundColor Gray
Write-Host "   Versao: $BUILD_TIMESTAMP" -ForegroundColor Gray

# PASSO 3: CRIAR DIRETORIO NO SERVIDOR
Write-Host ""
Write-Host "3. PREPARANDO SERVIDOR..." -ForegroundColor Cyan
Write-Host "   (Digite a senha quando solicitado)" -ForegroundColor Yellow
Write-Host ""

ssh $SERVER "mkdir -p $REMOTE_PATH"
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERRO ao criar diretorio!" -ForegroundColor Red
    exit 1
}

# PASSO 4: FAZER BACKUP
Write-Host ""
Write-Host "4. FAZENDO BACKUP..." -ForegroundColor Cyan

$BACKUP_DIR = "/root/backups/taskflow_web_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh $SERVER @"
if [ -f '$REMOTE_PATH/index.html' ]; then
    mkdir -p /root/backups
    cp -r $REMOTE_PATH $BACKUP_DIR
    echo 'Backup criado: $BACKUP_DIR'
else
    echo 'Sem conteudo para backup (primeira vez?)'
fi
"@

# PASSO 5: TRANSFERIR ARQUIVOS
Write-Host ""
Write-Host "5. TRANSFERINDO ARQUIVOS..." -ForegroundColor Cyan
Write-Host "   Isso pode demorar alguns minutos..." -ForegroundColor Yellow
Write-Host ""

# Limpar diretorio remoto
ssh $SERVER "rm -rf $REMOTE_PATH/*"

# Transferir com SCP recursivo
# IMPORTANTE: Transferir o CONTEUDO de build\web\, nao a pasta em si
scp -r build\web\* "${SERVER}:${REMOTE_PATH}/"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERRO ao transferir arquivos!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Tentando restaurar backup..." -ForegroundColor Yellow
    ssh $SERVER "if [ -d '$BACKUP_DIR' ]; then rm -rf $REMOTE_PATH/* && cp -r $BACKUP_DIR/* $REMOTE_PATH/; fi"
    exit 1
}

# PASSO 6: VERIFICAR TRANSFERENCIA
Write-Host ""
Write-Host "6. VERIFICANDO TRANSFERENCIA..." -ForegroundColor Cyan

$remoteVersion = ssh $SERVER "cat $REMOTE_PATH/version.txt 2>/dev/null || echo 'N/A'"
$remoteVersion = $remoteVersion.Trim()

if ($remoteVersion -eq $BUILD_TIMESTAMP) {
    Write-Host "   Versao confirmada: $remoteVersion" -ForegroundColor Green
} else {
    Write-Host "   AVISO: Versao no servidor: $remoteVersion (esperado: $BUILD_TIMESTAMP)" -ForegroundColor Yellow
}

$remoteFiles = ssh $SERVER "find $REMOTE_PATH -type f | wc -l"
$remoteFiles = [int]$remoteFiles.Trim()
Write-Host "   Arquivos no servidor: $remoteFiles de $fileCount" -ForegroundColor Gray

if ($remoteFiles -lt ($fileCount * 0.9)) {
    Write-Host ""
    Write-Host "AVISO: Poucos arquivos transferidos!" -ForegroundColor Yellow
    Write-Host "Esperado: $fileCount, Encontrado: $remoteFiles" -ForegroundColor Yellow
}

# PASSO 7: AJUSTAR PERMISSOES
Write-Host ""
Write-Host "7. AJUSTANDO PERMISSOES..." -ForegroundColor Cyan

ssh $SERVER "sudo chown -R www-data:www-data $REMOTE_PATH && sudo chmod -R 755 $REMOTE_PATH"

if ($LASTEXITCODE -eq 0) {
    Write-Host "   Permissoes ajustadas!" -ForegroundColor Green
} else {
    Write-Host "   AVISO: Nao foi possivel ajustar permissoes automaticamente" -ForegroundColor Yellow
}

# SUCESSO!
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEPLOY CONCLUIDO!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Acesse a aplicacao em:" -ForegroundColor Cyan
Write-Host "   http://212.85.0.249:8080/task2026/" -ForegroundColor Yellow
Write-Host "   ou" -ForegroundColor Gray
Write-Host "   http://taskflowv3.com.br/" -ForegroundColor Yellow
Write-Host ""
Write-Host "Versao do build: $BUILD_TIMESTAMP" -ForegroundColor Cyan
Write-Host ""
Write-Host "Dica: Se a versao nao atualizou no navegador:" -ForegroundColor Gray
Write-Host "   - Pressione Ctrl+Shift+R para forcar atualizacao" -ForegroundColor Gray
Write-Host "   - Ou limpe o cache do navegador" -ForegroundColor Gray
Write-Host ""
