# ============================================
# Verificar e Restaurar Deploy
# ============================================

$SERVER = "root@212.85.0.249"
$REMOTE_PATH = "/var/www/html/task2026"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VERIFICANDO ESTADO DO SERVIDOR" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se existe backup
Write-Host "1. Procurando backups..." -ForegroundColor Yellow
ssh $SERVER "ls -ldt ${REMOTE_PATH}_backup_* 2>/dev/null | head -5"

Write-Host ""
Write-Host "2. Verificando conteudo atual..." -ForegroundColor Yellow
ssh $SERVER "ls -lah $REMOTE_PATH/ | head -10"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "OPCOES:" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Se existe backup, podemos restaurar" -ForegroundColor Cyan
Write-Host "2. Ou fazer deploy completo (build + transferir)" -ForegroundColor Cyan
Write-Host ""
