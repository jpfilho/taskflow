# Script para mapear porta do supabase-db diretamente
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$COMPOSE_PATH = "/root/supabase/docker/docker-compose.yml"
$CONTAINER_NAME = "supabase-db"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Mapear Porta supabase-db Diretamente" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se ja esta mapeado
Write-Host "[1/4] Verificando se porta ja esta mapeada..." -ForegroundColor Yellow
$hasMapping = ssh ${SERVER_USER}@${SERVER_IP} "docker port $CONTAINER_NAME 5432 2>&1"
# Verificar se realmente esta mapeada (nao apenas se contem "5432" na mensagem de erro)
if ($hasMapping -match "0\.0\.0\.0:" -or $hasMapping -match "\[::\]:") {
    Write-Host "Porta ja esta mapeada: $hasMapping" -ForegroundColor Green
    Write-Host ""
    Write-Host "Use no N8N:" -ForegroundColor Yellow
    $portLine = ($hasMapping -split "`n")[0]
    if ($portLine -match "0\.0\.0\.0:(\d+)") {
        $mappedPort = $matches[1]
        Write-Host "  Host: $SERVER_IP" -ForegroundColor White
        Write-Host "  Port: $mappedPort" -ForegroundColor White
        Write-Host "  Database: postgres" -ForegroundColor White
        Write-Host "  User: postgres" -ForegroundColor White
        Write-Host "  Password: KhVAFkxwia0BttKJ0Z3gnbauuc9z3W5YmVd70WVuA" -ForegroundColor White
    }
    exit 0
} else {
    Write-Host "Porta NAO esta mapeada. Continuando..." -ForegroundColor Yellow
}

# Fazer backup
Write-Host "[2/4] Fazendo backup..." -ForegroundColor Yellow
$backupFile = "$COMPOSE_PATH.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh ${SERVER_USER}@${SERVER_IP} "cp $COMPOSE_PATH $backupFile"
Write-Host "Backup: $backupFile" -ForegroundColor Green

# Mostrar secao atual
Write-Host ""
Write-Host "[3/4] Mostrando secao 'db' atual..." -ForegroundColor Yellow
$currentSection = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 30 '^  db:' $COMPOSE_PATH | head -35"
Write-Host $currentSection -ForegroundColor Gray

# Adicionar mapeamento usando Python
Write-Host ""
Write-Host "[4/4] Adicionando mapeamento de porta 5433:5432..." -ForegroundColor Yellow

$pythonScript = @"
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Verificar se ja tem ports mapeado
if '5433:5432' in content or re.search(r'ports:\s*\n\s*-\s*["\']5433:5432', content):
    print("Mapeamento ja existe!")
    sys.exit(0)

# Procurar por 'restart:' na secao db e adicionar ports logo apos
lines = content.split('\n')
new_lines = []
in_db_section = False
ports_added = False
db_indent = 0

for i, line in enumerate(lines):
    # Detectar inicio da secao db
    if re.match(r'^\s*db:', line):
        in_db_section = True
        db_indent = len(line) - len(line.lstrip())
        new_lines.append(line)
        continue
    
    if in_db_section:
        # Verificar se ja tem ports
        if re.match(r'^\s*ports:', line):
            new_lines.append(line)
            # Verificar proxima linha
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                if '5433:5432' in next_line:
                    ports_added = True
                    new_lines.append(next_line)
                    continue
                elif re.match(r'^\s+-', next_line):
                    # Ja tem porta, adicionar a nossa
                    new_lines.append(' ' * (db_indent + 4) + '- "5433:5432"')
                    ports_added = True
            continue
        
        # Adicionar ports logo apos 'restart:'
        if 'restart:' in line and not ports_added:
            new_lines.append(line)
            # Adicionar ports na proxima linha
            new_lines.append(' ' * (db_indent + 2) + 'ports:')
            new_lines.append(' ' * (db_indent + 4) + '- "5433:5432"')
            ports_added = True
            continue
        
        # Verificar se saimos da secao db
        if line.strip() and not line.strip().startswith('#'):
            current_indent = len(line) - len(line.lstrip())
            if current_indent <= db_indent:
                if not ports_added:
                    # Adicionar antes de sair
                    new_lines.append(' ' * (db_indent + 2) + 'ports:')
                    new_lines.append(' ' * (db_indent + 4) + '- "5433:5432"')
                    ports_added = True
                in_db_section = False
    
    new_lines.append(line)

# Se ainda nao adicionou
if in_db_section and not ports_added:
    new_lines.append(' ' * (db_indent + 2) + 'ports:')
    new_lines.append(' ' * (db_indent + 4) + '- "5433:5432"')

with open(file_path, 'w') as f:
    f.write('\n'.join(new_lines))

print("Mapeamento adicionado!")
"@

$tempScript = "/tmp/add_db_port.py"
$pythonScript | ssh ${SERVER_USER}@${SERVER_IP} "cat > $tempScript && chmod +x $tempScript"
$result = ssh ${SERVER_USER}@${SERVER_IP} "python3 $tempScript $COMPOSE_PATH 2>&1"
Write-Host $result -ForegroundColor Gray

ssh ${SERVER_USER}@${SERVER_IP} "rm -f $tempScript"

# Verificar
$verify = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 10 '^  db:' $COMPOSE_PATH | grep '5433:5432'"
if ($verify) {
    Write-Host "Mapeamento adicionado com sucesso!" -ForegroundColor Green
    
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
        Write-Host "SSL: Desabilitado (Ignore SSL Issues)" -ForegroundColor White
        Write-Host ""
    }
} else {
    Write-Host "Falha ao adicionar mapeamento" -ForegroundColor Red
    Write-Host "Restaurando backup..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "cp $backupFile $COMPOSE_PATH"
    Write-Host ""
    Write-Host "Edite manualmente:" -ForegroundColor Yellow
    Write-Host "  ssh $SERVER_USER@$SERVER_IP" -ForegroundColor White
    Write-Host "  nano $COMPOSE_PATH" -ForegroundColor White
    Write-Host "  Adicione na secao 'db':" -ForegroundColor White
    Write-Host "    ports:" -ForegroundColor Gray
    Write-Host "      - \"5433:5432\"" -ForegroundColor Gray
}
