# ============================================
# EXECUTAR CORRECAO DO NGINX
# ============================================

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGINDO NGINX PARA SUPABASE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copiando script para o servidor..." -ForegroundColor Yellow
scp corrigir_nginx_supabase.sh "${SERVER}:/root/"

Write-Host ""
Write-Host "Executando no servidor..." -ForegroundColor Yellow
Write-Host ""
ssh $SERVER "chmod +x /root/corrigir_nginx_supabase.sh && /root/corrigir_nginx_supabase.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CORRECAO CONCLUIDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "PROXIMO PASSO:" -ForegroundColor Yellow
Write-Host "   1. Hot Restart no Flutter" -ForegroundColor White
Write-Host "   2. Tente fazer login novamente" -ForegroundColor White
Write-Host ""
