# ============================================
# VERIFICAR O QUE ESTA NO SERVIDOR
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICANDO SERVIDOR" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Verificando se o diretorio existe..." -ForegroundColor Yellow
ssh $SERVER "ls -la $REMOTE_PATH | head -20"

Write-Host ""
Write-Host "2. Contando arquivos no servidor..." -ForegroundColor Yellow
ssh $SERVER "find $REMOTE_PATH -type f | wc -l"

Write-Host ""
Write-Host "3. Verificando index.html..." -ForegroundColor Yellow
ssh $SERVER "ls -lh $REMOTE_PATH/index.html"

Write-Host ""
Write-Host "4. Verificando version.txt..." -ForegroundColor Yellow
ssh $SERVER "cat $REMOTE_PATH/version.txt 2>/dev/null || echo 'version.txt nao encontrado'"

Write-Host ""
Write-Host "5. Verificando permissoes..." -ForegroundColor Yellow
ssh $SERVER "ls -ld $REMOTE_PATH"

Write-Host ""
Write-Host "6. Comparando com local..." -ForegroundColor Yellow
$localFiles = (Get-ChildItem -Path "build\web" -Recurse -File).Count
Write-Host "   Arquivos locais: $localFiles"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
