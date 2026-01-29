# Atualizar Edge Functions para HTTP:8000
Write-Host "Atualizando Edge Functions para HTTP:8000..." -ForegroundColor Cyan

$SSHUser = "root"
$SSHHost = "212.85.0.249"
$SupabasePath = "/root/supabase"

# Preparar .env localmente
Copy-Item "supabase\functions\telegram-webhook\env_file.txt" "supabase\functions\telegram-webhook\.env" -Force
Copy-Item "supabase\functions\telegram-send\env_file.txt" "supabase\functions\telegram-send\.env" -Force

Write-Host "Copiando arquivos..." -ForegroundColor Yellow

# Copiar para servidor
scp "supabase\functions\telegram-webhook\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-webhook/"
scp "supabase\functions\telegram-send\.env" "${SSHUser}@${SSHHost}:${SupabasePath}/volumes/functions/telegram-send/"

Write-Host ""
Write-Host "Reiniciando container..." -ForegroundColor Yellow

# Reiniciar
ssh ${SSHUser}@${SSHHost} "cd ${SupabasePath}; docker-compose restart edge-functions"

Write-Host ""
Write-Host "CONCLUIDO!" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANTE: O webhook do Telegram continua em HTTPS" -ForegroundColor Cyan
Write-Host "Apenas o Flutter e as Edge Functions usam HTTP:8000" -ForegroundColor Cyan
Write-Host ""
