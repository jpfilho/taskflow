# Instrucoes para configurar conexao N8N com Postgres Supabase
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$SUPABASE_DIR = "/root/supabase"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Configuracao N8N - Postgres Supabase" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "A conexao esta pronta! Use as seguintes configuracoes:" -ForegroundColor Green
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "CONFIGURACAO N8N:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Host: $SERVER_IP" -ForegroundColor White
Write-Host "Port: 5432" -ForegroundColor White
Write-Host "Database: postgres" -ForegroundColor White
Write-Host "User: postgres" -ForegroundColor White
Write-Host "Password: [obtenha do arquivo .env do Supabase]" -ForegroundColor White
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "OBTER SENHA:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Execute no servidor:" -ForegroundColor White
Write-Host "  ssh $SERVER_USER@$SERVER_IP" -ForegroundColor Gray
Write-Host ""
Write-Host "Depois execute um dos comandos:" -ForegroundColor White
Write-Host "  cat $SUPABASE_DIR/.env | grep POSTGRES_PASSWORD" -ForegroundColor Gray
Write-Host "  OU" -ForegroundColor Gray
Write-Host "  cat $SUPABASE_DIR/docker/.env | grep POSTGRES_PASSWORD" -ForegroundColor Gray
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "NOTAS:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "- A porta 5432 ja esta mapeada via supabase-pooler" -ForegroundColor Gray
Write-Host "- Se 'postgres' nao funcionar, tente 'supabase_admin'" -ForegroundColor Gray
Write-Host "- O database geralmente e 'postgres'" -ForegroundColor Gray
Write-Host ""
