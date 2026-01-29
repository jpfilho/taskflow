# Script para mostrar exatamente o que precisa ser editado
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$COMPOSE_PATH = "/root/supabase/docker/docker-compose.yml"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Instrucoes para Edicao Manual" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Mostrar secao atual
Write-Host "Secao atual do supabase-db:" -ForegroundColor Yellow
$section = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 30 'supabase-db:' $COMPOSE_PATH | head -35"
Write-Host $section -ForegroundColor Gray

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "O QUE FAZER:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Acesse o servidor:" -ForegroundColor White
Write-Host "   ssh root@212.85.0.249" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Edite o arquivo:" -ForegroundColor White
Write-Host "   nano $COMPOSE_PATH" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Encontre a linha que contem 'supabase-db:'" -ForegroundColor White
Write-Host ""
Write-Host "4. Logo APOS essa linha, adicione estas duas linhas:" -ForegroundColor White
Write-Host "   (mantenha a mesma indentacao das outras propriedades)" -ForegroundColor Gray
Write-Host ""
Write-Host "   ports:" -ForegroundColor Cyan
Write-Host '     - "5432:5432"' -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Salve: Ctrl+O, Enter, Ctrl+X" -ForegroundColor White
Write-Host ""
Write-Host "6. Reinicie o container:" -ForegroundColor White
Write-Host "   cd /root/supabase/docker" -ForegroundColor Gray
Write-Host "   docker-compose up -d supabase-db" -ForegroundColor Gray
Write-Host ""
Write-Host "7. Verifique se funcionou:" -ForegroundColor White
Write-Host '   docker port supabase-db 5432' -ForegroundColor Gray
Write-Host ""
