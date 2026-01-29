# Script para verificar status completo do Supabase
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verificar Status Supabase" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar containers Supabase
Write-Host "[1/6] Verificando containers Supabase..." -ForegroundColor Yellow
$containers = ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose ps 2>&1"
Write-Host $containers -ForegroundColor Gray

# 2. Verificar container db especificamente
Write-Host ""
Write-Host "[2/6] Verificando container supabase-db..." -ForegroundColor Yellow
$dbStatus = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=supabase-db' --format '{{.Names}} - {{.Status}}' 2>&1"
Write-Host $dbStatus -ForegroundColor Gray

if ($dbStatus -match "Up") {
    Write-Host "Container db esta rodando!" -ForegroundColor Green
} else {
    Write-Host "ERRO: Container db NAO esta rodando!" -ForegroundColor Red
}

# 3. Verificar volumes
Write-Host ""
Write-Host "[3/6] Verificando volumes do Postgres..." -ForegroundColor Yellow
$volumes = ssh ${SERVER_USER}@${SERVER_IP} "docker volume ls | grep supabase 2>&1"
Write-Host $volumes -ForegroundColor Gray

# 4. Verificar se consegue conectar ao Postgres
Write-Host ""
Write-Host "[4/6] Testando conexao ao Postgres..." -ForegroundColor Yellow
$pgTest = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -d postgres -c 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '\''public'\'';' 2>&1"
Write-Host "Numero de tabelas no schema public: $pgTest" -ForegroundColor Gray

if ($pgTest -match "\d+") {
    Write-Host "Postgres esta respondendo e tem tabelas!" -ForegroundColor Green
} else {
    Write-Host "AVISO: Nao foi possivel verificar tabelas" -ForegroundColor Yellow
}

# 5. Verificar se o Supabase Studio esta acessivel
Write-Host ""
Write-Host "[5/6] Verificando Supabase Studio..." -ForegroundColor Yellow
$studioStatus = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=supabase-studio' --format '{{.Names}} - {{.Status}}' 2>&1"
Write-Host $studioStatus -ForegroundColor Gray

if ($studioStatus -match "Up") {
    Write-Host "Supabase Studio esta rodando!" -ForegroundColor Green
} else {
    Write-Host "AVISO: Supabase Studio pode nao estar rodando" -ForegroundColor Yellow
}

# 6. Verificar logs do db para erros recentes
Write-Host ""
Write-Host "[6/6] Verificando logs recentes do db..." -ForegroundColor Yellow
$logs = ssh ${SERVER_USER}@${SERVER_IP} "docker logs supabase-db --tail 20 2>&1"
Write-Host $logs -ForegroundColor Gray

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Diagnostico" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se ha erros criticos
if ($logs -match "FATAL" -or $logs -match "ERROR" -or $logs -match "panic") {
    Write-Host "ERRO: Encontrados erros criticos nos logs!" -ForegroundColor Red
    Write-Host "Verifique os logs completos:" -ForegroundColor Yellow
    Write-Host "  ssh $SERVER_USER@$SERVER_IP 'docker logs supabase-db'" -ForegroundColor White
} else {
    Write-Host "Nenhum erro critico encontrado nos logs recentes." -ForegroundColor Green
}

Write-Host ""
Write-Host "Se o projeto nao aparece no Supabase Studio:" -ForegroundColor Yellow
Write-Host "1. Verifique se o Supabase Studio esta acessivel em http://$SERVER_IP:3000" -ForegroundColor White
Write-Host "2. Verifique se os volumes estao montados corretamente" -ForegroundColor White
Write-Host "3. Verifique se o banco de dados tem as tabelas do projeto" -ForegroundColor White
Write-Host "4. Tente reiniciar todos os servicos: cd /root/supabase/docker && docker-compose restart" -ForegroundColor White
Write-Host ""
