# Script para restaurar backup e mapear porta corretamente
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$COMPOSE_PATH = "/root/supabase/docker/docker-compose.yml"
$CONTAINER_NAME = "supabase-db"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Restaurar Backup e Mapear Porta" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Restaurar backup mais recente
Write-Host "[1/5] Restaurando backup..." -ForegroundColor Yellow
$backupFile = ssh ${SERVER_USER}@${SERVER_IP} "ls -t $COMPOSE_PATH.backup_* 2>/dev/null | head -1"
if ($backupFile) {
    ssh ${SERVER_USER}@${SERVER_IP} "cp $backupFile $COMPOSE_PATH"
    Write-Host "Backup restaurado: $backupFile" -ForegroundColor Green
} else {
    Write-Host "Nenhum backup encontrado!" -ForegroundColor Red
    exit 1
}

# Fazer novo backup
Write-Host ""
Write-Host "[2/5] Criando novo backup..." -ForegroundColor Yellow
$newBackup = "$COMPOSE_PATH.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh ${SERVER_USER}@${SERVER_IP} "cp $COMPOSE_PATH $newBackup"
Write-Host "Novo backup: $newBackup" -ForegroundColor Green

# Mostrar secao db atual
Write-Host ""
Write-Host "[3/5] Mostrando secao 'db' atual..." -ForegroundColor Yellow
$currentSection = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 5 '^  db:' $COMPOSE_PATH | head -10"
Write-Host $currentSection -ForegroundColor Gray

# Adicionar mapeamento usando sed (mais simples e confiavel)
Write-Host ""
Write-Host "[4/5] Adicionando mapeamento de porta 5433:5432..." -ForegroundColor Yellow

# Usar sed para adicionar apos 'restart:' na secao db
$sedCommand = "sed -i '/^  db:/,/^  [^ ]/ { /restart: unless-stopped/a\    ports:\n      - \"5433:5432\"\n  }' $COMPOSE_PATH"
# Melhor: usar awk ou Python mais simples
$pythonScript = @"
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    lines = f.readlines()

new_lines = []
in_db = False
ports_added = False
db_indent = 0

for i, line in enumerate(lines):
    if re.match(r'^\s*db:', line):
        in_db = True
        db_indent = len(line) - len(line.lstrip())
        new_lines.append(line)
        continue
    
    if in_db:
        # Verificar se ja tem ports
        if 'ports:' in line.lower() and not line.strip().startswith('#'):
            new_lines.append(line)
            if i + 1 < len(lines) and '5433:5432' in lines[i + 1]:
                ports_added = True
                new_lines.append(lines[i + 1])
                continue
            continue
        
        # Adicionar apos restart:
        if 'restart:' in line and not ports_added:
            new_lines.append(line)
            new_lines.append(' ' * (db_indent + 2) + 'ports:\n')
            new_lines.append(' ' * (db_indent + 4) + '- "5433:5432"\n')
            ports_added = True
            continue
        
        # Verificar se saiu da secao
        if line.strip() and not line.strip().startswith('#'):
            current_indent = len(line) - len(line.lstrip())
            if current_indent <= db_indent:
                if not ports_added:
                    new_lines.append(' ' * (db_indent + 2) + 'ports:\n')
                    new_lines.append(' ' * (db_indent + 4) + '- "5433:5432"\n')
                in_db = False
    
    new_lines.append(line)

with open(file_path, 'w') as f:
    f.writelines(new_lines)

print("OK" if ports_added else "ERRO")
"@

$tempScript = "/tmp/add_port_fix.py"
$pythonScript | ssh ${SERVER_USER}@${SERVER_IP} "cat > $tempScript"
$result = ssh ${SERVER_USER}@${SERVER_IP} "python3 $tempScript $COMPOSE_PATH 2>&1"
Write-Host $result -ForegroundColor Gray

ssh ${SERVER_USER}@${SERVER_IP} "rm -f $tempScript"

# Verificar
Write-Host ""
Write-Host "[5/5] Verificando mapeamento..." -ForegroundColor Yellow
$verify = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 3 '^  db:' $COMPOSE_PATH | grep -A 2 'ports:' | grep '5433:5432'"
if ($verify) {
    Write-Host "Mapeamento adicionado!" -ForegroundColor Green
    
    # Validar docker-compose
    $validate = ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose config -q 2>&1"
    if ($LASTEXITCODE -eq 0 -or $validate -match "valid") {
        Write-Host "docker-compose.yml valido!" -ForegroundColor Green
        
        # Reiniciar container
        Write-Host ""
        Write-Host "Reiniciando container..." -ForegroundColor Yellow
        ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose up -d db"
        
        Start-Sleep -Seconds 3
        
        # Verificar porta
        $portCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker port $CONTAINER_NAME 5432 2>&1"
        if ($portCheck -match "5433") {
            Write-Host "Porta mapeada: $portCheck" -ForegroundColor Green
            Write-Host ""
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "CONFIGURACAO N8N:" -ForegroundColor Yellow
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Host: $SERVER_IP" -ForegroundColor White
            Write-Host "Port: 5433" -ForegroundColor White
            Write-Host "Database: postgres" -ForegroundColor White
            Write-Host "User: postgres" -ForegroundColor White
            Write-Host "Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor White
            Write-Host "SSL: Desabilitado" -ForegroundColor White
            Write-Host ""
        }
    } else {
        Write-Host "ERRO: docker-compose.yml invalido!" -ForegroundColor Red
        Write-Host $validate -ForegroundColor Gray
        Write-Host "Restaurando backup..." -ForegroundColor Yellow
        ssh ${SERVER_USER}@${SERVER_IP} "cp $newBackup $COMPOSE_PATH"
    }
} else {
    Write-Host "Falha ao adicionar mapeamento" -ForegroundColor Red
    Write-Host "Restaurando backup..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "cp $newBackup $COMPOSE_PATH"
}
