# Script para resolver conflito de containers e reiniciar o db
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Resolver Conflito e Reiniciar DB" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se supabase-vector existe e está causando conflito
Write-Host "[1/5] Verificando containers conflitantes..." -ForegroundColor Yellow
$vectorExists = ssh ${SERVER_USER}@${SERVER_IP} "docker ps -a --filter 'name=supabase-vector' --format '{{.Names}}' 2>&1"
if ($vectorExists -match "supabase-vector") {
    Write-Host "Container supabase-vector encontrado." -ForegroundColor Yellow
    Write-Host "NOTA: Remover este container e SEGURO - nao afeta dados ou configuracao." -ForegroundColor Cyan
    Write-Host "      Os dados estao em volumes persistentes e o container pode ser recriado." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Removendo container conflitante..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "docker stop supabase-vector 2>/dev/null; docker rm supabase-vector 2>/dev/null"
    Write-Host "Container removido! (veja SEGURANCA_REMOCAO_VECTOR.md para detalhes)" -ForegroundColor Green
} else {
    Write-Host "Nenhum conflito detectado." -ForegroundColor Green
}

# Verificar qual porta está mapeada no docker-compose.yml
Write-Host ""
Write-Host "[2/5] Verificando mapeamento de porta no docker-compose.yml..." -ForegroundColor Yellow
$dbSection = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 10 '^  db:' /root/supabase/docker/docker-compose.yml | head -15 2>&1"
Write-Host "Secao db atual:" -ForegroundColor Gray
Write-Host $dbSection -ForegroundColor Gray
Write-Host ""

$portMapping = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 5 '^  db:' /root/supabase/docker/docker-compose.yml | grep -E '(ports:|5432|5433)' 2>&1"
if ($portMapping -match "5432:5432") {
    Write-Host "ERRO: docker-compose.yml tem 5432:5432 (conflita com pooler)!" -ForegroundColor Red
    Write-Host "Corrigindo para 5433:5432..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "sed -i 's/\"5432:5432\"/\"5433:5432\"/g' /root/supabase/docker/docker-compose.yml"
    ssh ${SERVER_USER}@${SERVER_IP} "sed -i 's/5432:5432/5433:5432/g' /root/supabase/docker/docker-compose.yml"
    Write-Host "Corrigido!" -ForegroundColor Green
} elseif ($portMapping -match "5433:5432") {
    Write-Host "Mapeamento correto (5433:5432) encontrado." -ForegroundColor Green
} else {
    Write-Host "AVISO: Nenhum mapeamento de porta encontrado na secao db." -ForegroundColor Yellow
    Write-Host "O docker-compose.yml precisa ter 'ports: - \"5433:5432\"' na secao db." -ForegroundColor Yellow
    Write-Host "Execute a edicao manual conforme EDICAO_MANUAL_PORTA_POSTGRES.md" -ForegroundColor Yellow
    exit 1
}

# Verificar qual container está usando a porta 5432
Write-Host ""
Write-Host "[3/5] Verificando qual container usa a porta 5432..." -ForegroundColor Yellow
$portUser = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --format '{{.Names}}' | xargs -I {} sh -c 'docker port {} 2>/dev/null | grep 5432 && echo {}' 2>&1"
if ($portUser) {
    Write-Host "Porta 5432 em uso por: $portUser" -ForegroundColor Yellow
    Write-Host "(Isso e normal - o pooler usa 5432, o db deve usar 5433)" -ForegroundColor Cyan
}

# Parar o serviço db
Write-Host ""
Write-Host "[4/5] Parando serviço db..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose stop db 2>&1"
Write-Host "Servico db parado." -ForegroundColor Green

# Remover o container db para evitar conflito de nome
Write-Host ""
Write-Host "[5/5] Removendo container db para recriacao..." -ForegroundColor Yellow
ssh ${SERVER_USER}@${SERVER_IP} "docker stop supabase-db 2>/dev/null; docker rm supabase-db 2>/dev/null"
Write-Host "Container db removido." -ForegroundColor Green

# Reiniciar o serviço db (recria automaticamente com nova config)
Write-Host ""
Write-Host "Reiniciando serviço db..." -ForegroundColor Yellow
$result = ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose up -d db 2>&1"
Write-Host $result -ForegroundColor Gray

# Verificar se funcionou
Start-Sleep -Seconds 3
Write-Host ""
Write-Host "Verificando porta..." -ForegroundColor Yellow
$portCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker port supabase-db 5432 2>&1"
if ($portCheck -match "0\.0\.0\.0:" -or $portCheck -match "\[::\]:") {
    Write-Host "SUCESSO! Porta mapeada: $portCheck" -ForegroundColor Green
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "CONFIGURACAO N8N:" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    # Extrair porta do output (pode ser 0.0.0.0:5433 ou [::]:5433)
    $mappedPort = "5433"
    if ($portCheck -match "0\.0\.0\.0:(\d+)") {
        $mappedPort = $matches[1]
    } elseif ($portCheck -match "\[::\]:(\d+)") {
        $mappedPort = $matches[1]
    } elseif ($portCheck -match ":(\d+)") {
        $mappedPort = $matches[1]
    }
    Write-Host "Host: $SERVER_IP" -ForegroundColor White
    Write-Host "Port: $mappedPort" -ForegroundColor White
    Write-Host "Database: postgres" -ForegroundColor White
    Write-Host "User: postgres" -ForegroundColor White
    Write-Host "Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor White
    Write-Host "SSL: Desabilitado" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "ERRO: Porta nao foi mapeada corretamente!" -ForegroundColor Red
    Write-Host "Verifique o docker-compose.yml manualmente." -ForegroundColor Yellow
}
