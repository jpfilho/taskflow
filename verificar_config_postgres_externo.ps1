# Script para verificar configuracoes do Postgres que podem bloquear conexoes externas
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Verificar Config Postgres Externa" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar listen_addresses no postgresql.conf
Write-Host "[1/3] Verificando listen_addresses..." -ForegroundColor Yellow
$listenAddr = ssh ${SERVER_USER}@${SERVER_IP} 'docker exec supabase-db psql -U postgres -t -c "SHOW listen_addresses;" 2>&1'
Write-Host "listen_addresses: $listenAddr" -ForegroundColor Gray
if ($listenAddr -match "\*" -or $listenAddr -match "0\.0\.0\.0" -or $listenAddr -match "all") {
    Write-Host "OK: Postgres aceita conexoes de qualquer endereco" -ForegroundColor Green
} else {
    Write-Host "AVISO: listen_addresses pode estar restrito" -ForegroundColor Yellow
}

# Verificar port
Write-Host ""
Write-Host "[2/3] Verificando porta do Postgres..." -ForegroundColor Yellow
$pgPort = ssh ${SERVER_USER}@${SERVER_IP} 'docker exec supabase-db psql -U postgres -t -c "SHOW port;" 2>&1'
Write-Host "Porta Postgres: $pgPort" -ForegroundColor Gray
if ($pgPort -match "5432") {
    Write-Host "OK: Postgres esta na porta 5432 (mapeada para 5433 no host)" -ForegroundColor Green
} else {
    Write-Host "AVISO: Porta diferente de 5432" -ForegroundColor Yellow
}

# Verificar pg_hba.conf (pode estar bloqueando conexoes externas)
Write-Host ""
Write-Host "[3/3] Verificando pg_hba.conf (regras de autenticacao)..." -ForegroundColor Yellow
$hbaRules = ssh ${SERVER_USER}@${SERVER_IP} 'docker exec supabase-db cat /etc/postgresql/postgresql.conf 2>/dev/null | grep -i hba || docker exec supabase-db find /var/lib/postgresql -name pg_hba.conf 2>/dev/null | head -1 | xargs cat 2>/dev/null | grep -v "^#" | grep -v "^$" | head -10 2>&1'
if ($hbaRules) {
    Write-Host "Regras pg_hba.conf encontradas:" -ForegroundColor Gray
    Write-Host $hbaRules -ForegroundColor Gray
} else {
    Write-Host "Nao foi possivel ler pg_hba.conf (pode estar em volume)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Nota:" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Se o Postgres nao aceita conexoes externas, pode ser necessario:" -ForegroundColor White
Write-Host "1. Configurar listen_addresses = '*' no postgresql.conf" -ForegroundColor White
Write-Host "2. Adicionar regra em pg_hba.conf permitindo conexoes do N8N" -ForegroundColor White
Write-Host "3. Reiniciar o container db" -ForegroundColor White
Write-Host ""
