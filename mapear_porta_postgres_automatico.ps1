# Script para mapear porta do Postgres Supabase automaticamente
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$CONTAINER_NAME = "supabase-db"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Mapear Porta Postgres - Automático" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Encontrar docker-compose.yml
Write-Host "[1/6] Procurando docker-compose.yml do Supabase..." -ForegroundColor Yellow
$composePath = ssh ${SERVER_USER}@${SERVER_IP} "find /opt /home /root -name 'docker-compose.yml' -o -name 'docker-compose.yaml' 2>/dev/null | xargs grep -l 'supabase-db' 2>/dev/null | head -1"
if (-not $composePath) {
    $composePath = ssh ${SERVER_USER}@${SERVER_IP} "find /opt/supabase /root/supabase /home/*/supabase -name 'docker-compose.yml' 2>/dev/null | head -1"
}

if (-not $composePath) {
    Write-Host "❌ docker-compose.yml não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "O Supabase pode estar usando outra forma de instalação." -ForegroundColor Yellow
    Write-Host "Execute: .\verificar_postgres_docker.ps1 para mais detalhes." -ForegroundColor White
    exit 1
}

Write-Host "✅ Arquivo encontrado: $composePath" -ForegroundColor Green

# 2. Verificar se porta já está mapeada
Write-Host ""
Write-Host "[2/6] Verificando se porta já está mapeada..." -ForegroundColor Yellow
$hasPortMapping = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 15 'supabase-db:' $composePath | grep -E '5432:5432|0.0.0.0:5432'"
if ($hasPortMapping) {
    Write-Host "✅ Porta já está mapeada!" -ForegroundColor Green
    Write-Host $hasPortMapping -ForegroundColor Gray
    Write-Host ""
    Write-Host "Reiniciando container para garantir que está ativo..." -ForegroundColor Yellow
    $composeDir = ssh ${SERVER_USER}@${SERVER_IP} "dirname $composePath"
    ssh ${SERVER_USER}@${SERVER_IP} "cd $composeDir && docker-compose restart $CONTAINER_NAME"
    Write-Host "✅ Container reiniciado!" -ForegroundColor Green
    exit 0
}

Write-Host "❌ Porta NÃO está mapeada. Adicionando mapeamento..." -ForegroundColor Yellow

# 3. Fazer backup do arquivo
Write-Host ""
Write-Host "[3/6] Fazendo backup do docker-compose.yml..." -ForegroundColor Yellow
$backupPath = "$composePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh ${SERVER_USER}@${SERVER_IP} "cp $composePath $backupPath"
Write-Host "✅ Backup criado: $backupPath" -ForegroundColor Green

# 4. Adicionar mapeamento de porta usando método simples
Write-Host ""
Write-Host "[4/6] Adicionando mapeamento de porta..." -ForegroundColor Yellow

# Método simples: usar awk para adicionar após a linha supabase-db:
$addPortsScript = @"
#!/bin/bash
FILE="$composePath"

# Verificar se já tem mapeamento
if grep -q '5432:5432' "$FILE"; then
    echo "Porta já mapeada!"
    exit 0
fi

# Encontrar linha supabase-db: e adicionar ports após ela
awk '
/^[[:space:]]*supabase-db:/ {
    print
    getline
    # Se próxima linha não é ports:, adicionar
    if (!/^[[:space:]]*ports:/) {
        # Determinar indentação (assumindo 2 espaços)
        match($0, /^[[:space:]]*/)
        indent = substr($0, 1, RLENGTH)
        print indent "  ports:"
        print indent "    - \"5432:5432\""
    }
    print
    next
}
{ print }
' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

echo "Mapeamento adicionado!"
"@

# Salvar e executar script
$tempScript = "/tmp/add_ports.sh"
$addPortsScript | ssh ${SERVER_USER}@${SERVER_IP} "cat > $tempScript && chmod +x $tempScript && bash $tempScript"
$result = ssh ${SERVER_USER}@${SERVER_IP} "bash $tempScript 2>&1"
Write-Host $result -ForegroundColor Gray

# Limpar
ssh ${SERVER_USER}@${SERVER_IP} "rm -f $tempScript"

# 5. Verificar se foi adicionado corretamente
Write-Host ""
Write-Host "[5/6] Verificando se mapeamento foi adicionado..." -ForegroundColor Yellow
$verifyMapping = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 15 'supabase-db:' $composePath | grep -E 'ports:|5432:5432'"
if ($verifyMapping -match "5432:5432") {
    Write-Host "✅ Mapeamento adicionado com sucesso!" -ForegroundColor Green
    Write-Host $verifyMapping -ForegroundColor Gray
} else {
    Write-Host "❌ Erro ao adicionar mapeamento!" -ForegroundColor Red
    Write-Host "Restaurando backup..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "cp $backupPath $composePath"
    Write-Host "Backup restaurado. Edite manualmente o arquivo." -ForegroundColor Yellow
    exit 1
}

# 6. Reiniciar container
Write-Host ""
Write-Host "[6/6] Reiniciando container..." -ForegroundColor Yellow
$composeDir = ssh ${SERVER_USER}@${SERVER_IP} "dirname $composePath"
$restartResult = ssh ${SERVER_USER}@${SERVER_IP} "cd $composeDir && docker-compose up -d $CONTAINER_NAME 2>&1"
Write-Host $restartResult -ForegroundColor Gray

# Verificar se container está rodando
Start-Sleep -Seconds 3
$containerStatus = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=$CONTAINER_NAME' --format '{{.Status}}'"
if ($containerStatus -match "Up") {
    Write-Host "✅ Container está rodando!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Verifique o status do container manualmente" -ForegroundColor Yellow
}

# Verificar mapeamento de porta
Write-Host ""
Write-Host "Verificando mapeamento de porta..." -ForegroundColor Yellow
$portCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker port $CONTAINER_NAME 5432 2>&1"
if ($portCheck -match "5432") {
    Write-Host "✅ Porta mapeada com sucesso!" -ForegroundColor Green
    Write-Host $portCheck -ForegroundColor Gray
} else {
    Write-Host "⚠️ Porta pode não estar mapeada. Verifique manualmente." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Concluído!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuração no N8N:" -ForegroundColor Yellow
Write-Host "  Host: 212.85.0.249" -ForegroundColor White
Write-Host "  Port: 5432" -ForegroundColor White
Write-Host "  Database: postgres" -ForegroundColor White
Write-Host "  User: postgres" -ForegroundColor White
Write-Host "  Password: [senha do Supabase]" -ForegroundColor White
Write-Host "  SSL: Prefer (ou desabilitado)" -ForegroundColor White
Write-Host ""
Write-Host "Teste a conexão no N8N agora!" -ForegroundColor Green
Write-Host ""
