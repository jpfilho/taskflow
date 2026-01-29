# Script para testar diferentes usuarios do Postgres
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$PASSWORD = "KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testar Usuarios Postgres" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Listar usuarios disponiveis
Write-Host "Listando usuarios do Postgres..." -ForegroundColor Yellow
$users = ssh ${SERVER_USER}@${SERVER_IP} "docker exec supabase-db psql -U postgres -d postgres -t -c \"SELECT usename FROM pg_user WHERE usename NOT LIKE 'pg_%';\" 2>&1"
Write-Host "Usuarios encontrados:" -ForegroundColor Green
Write-Host $users -ForegroundColor Gray

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "CONFIGURACOES PARA TESTAR NO N8N:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "OPCAO 1 - Usuario postgres:" -ForegroundColor Cyan
Write-Host "  Host: $SERVER_IP" -ForegroundColor White
Write-Host "  Port: 5432" -ForegroundColor White
Write-Host "  Database: postgres" -ForegroundColor White
Write-Host "  User: postgres" -ForegroundColor White
Write-Host "  Password: $PASSWORD" -ForegroundColor White
Write-Host "  SSL: Desabilitado (Ignore SSL Issues)" -ForegroundColor White
Write-Host ""

Write-Host "OPCAO 2 - Usuario supabase_admin:" -ForegroundColor Cyan
Write-Host "  Host: $SERVER_IP" -ForegroundColor White
Write-Host "  Port: 5432" -ForegroundColor White
Write-Host "  Database: postgres" -ForegroundColor White
Write-Host "  User: supabase_admin" -ForegroundColor White
Write-Host "  Password: $PASSWORD" -ForegroundColor White
Write-Host "  SSL: Desabilitado (Ignore SSL Issues)" -ForegroundColor White
Write-Host ""

Write-Host "OPCAO 3 - Verificar senha do supabase_admin:" -ForegroundColor Cyan
Write-Host "  Execute no servidor:" -ForegroundColor White
Write-Host "    ssh $SERVER_USER@$SERVER_IP" -ForegroundColor Gray
Write-Host "    cat /root/supabase/docker/.env | grep SUPABASE" -ForegroundColor Gray
Write-Host ""
