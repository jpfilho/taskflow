# Script DIRETO para mapear porta do Postgres Supabase
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$CONTAINER_NAME = "supabase-db"
$COMPOSE_PATH = "/root/supabase/docker/docker-compose.yml"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Mapear Porta Postgres - Método Direto" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se arquivo existe
Write-Host "[1/5] Verificando arquivo docker-compose.yml..." -ForegroundColor Yellow
$fileExists = ssh ${SERVER_USER}@${SERVER_IP} "test -f $COMPOSE_PATH && echo 'existe' || echo 'nao_existe'"
if ($fileExists -ne "existe") {
    Write-Host "❌ Arquivo não encontrado: $COMPOSE_PATH" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Arquivo encontrado!" -ForegroundColor Green

# 2. Verificar se já está mapeado
Write-Host ""
Write-Host "[2/5] Verificando se porta já está mapeada..." -ForegroundColor Yellow
$hasMapping = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 15 'supabase-db:' $COMPOSE_PATH | grep '5432:5432'"
if ($hasMapping) {
    Write-Host "✅ Porta já está mapeada!" -ForegroundColor Green
    Write-Host "Reiniciando container..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose restart $CONTAINER_NAME"
    Write-Host "✅ Pronto!" -ForegroundColor Green
    exit 0
}

# 3. Mostrar estrutura atual da seção
Write-Host ""
Write-Host "[3/5] Mostrando estrutura atual da seção supabase-db..." -ForegroundColor Yellow
$currentSection = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 30 'supabase-db:' $COMPOSE_PATH | head -35"
Write-Host $currentSection -ForegroundColor Gray

# 4. Fazer backup
Write-Host ""
Write-Host "[4/5] Fazendo backup..." -ForegroundColor Yellow
$backupFile = "$COMPOSE_PATH.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh ${SERVER_USER}@${SERVER_IP} "cp $COMPOSE_PATH $backupFile"
Write-Host "✅ Backup: $backupFile" -ForegroundColor Green

# 5. Adicionar mapeamento usando método mais simples
Write-Host ""
Write-Host "[5/5] Adicionando mapeamento de porta..." -ForegroundColor Yellow

# Criar script Python mais simples e direto
$pythonScript = @"
import sys
import re

file_path = sys.argv[1]

# Ler arquivo
with open(file_path, 'r') as f:
    content = f.read()

# Verificar se já tem
if '5432:5432' in content:
    print("Já existe mapeamento!")
    sys.exit(0)

# Encontrar linha supabase-db: e adicionar ports após ela
lines = content.split('\n')
new_lines = []
added = False

for i, line in enumerate(lines):
    new_lines.append(line)
    
    # Se encontrou supabase-db:
    if re.match(r'^\s*supabase-db:', line):
        # Determinar indentação
        indent = len(line) - len(line.lstrip())
        
        # Verificar próxima linha
        if i + 1 < len(lines):
            next_line = lines[i + 1]
            # Se não tem ports: na próxima linha, adicionar
            if 'ports:' not in next_line.lower():
                new_lines.append(' ' * (indent + 2) + 'ports:')
                new_lines.append(' ' * (indent + 4) + '- "5432:5432"')
                added = True
        else:
            # Última linha
            new_lines.append(' ' * (indent + 2) + 'ports:')
            new_lines.append(' ' * (indent + 4) + '- "5432:5432"')
            added = True

# Escrever
with open(file_path, 'w') as f:
    f.write('\n'.join(new_lines))

if added:
    print("Mapeamento adicionado!")
else:
    print("Não foi possível adicionar (pode já existir)")
"@

# Salvar script
$tempPy = "/tmp/add_port_direct.py"
$pythonScript | ssh ${SERVER_USER}@${SERVER_IP} "cat > $tempPy"
$result = ssh ${SERVER_USER}@${SERVER_IP} "python3 $tempPy $COMPOSE_PATH 2>&1"
Write-Host $result -ForegroundColor Gray

# Limpar
ssh ${SERVER_USER}@${SERVER_IP} "rm -f $tempPy"

# Verificar resultado
Write-Host ""
Write-Host "Verificando resultado..." -ForegroundColor Yellow
$verify = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 15 'supabase-db:' $COMPOSE_PATH | head -20"
Write-Host $verify -ForegroundColor Gray

$hasPorts = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 15 'supabase-db:' $COMPOSE_PATH | grep '5432:5432'"
if ($hasPorts) {
    Write-Host ""
    Write-Host "✅ Mapeamento adicionado com sucesso!" -ForegroundColor Green
    
    # Reiniciar container
    Write-Host ""
    Write-Host "Reiniciando container..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "cd /root/supabase/docker && docker-compose up -d $CONTAINER_NAME"
    
    Start-Sleep -Seconds 3
    
    # Verificar porta
    $portCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker port $CONTAINER_NAME 5432 2>&1"
    if ($portCheck -match "5432") {
        Write-Host "✅ Porta mapeada: $portCheck" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Verifique: docker port $CONTAINER_NAME" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "❌ Mapeamento não foi adicionado" -ForegroundColor Red
    Write-Host "Restaurando backup..." -ForegroundColor Yellow
    ssh ${SERVER_USER}@${SERVER_IP} "cp $backupFile $COMPOSE_PATH"
    Write-Host ""
    Write-Host "SOLUÇÃO MANUAL:" -ForegroundColor Yellow
    Write-Host "ssh root@212.85.0.249" -ForegroundColor White
    Write-Host "nano $COMPOSE_PATH" -ForegroundColor White
    Write-Host ""
    Write-Host "Adicione após 'supabase-db:'" -ForegroundColor White
    Write-Host "  ports:" -ForegroundColor Gray
    Write-Host "    - `"5432:5432`"" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Concluído!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configure no N8N:" -ForegroundColor Yellow
Write-Host "  Host: 212.85.0.249" -ForegroundColor White
Write-Host "  Port: 5432" -ForegroundColor White
Write-Host "  Database: postgres" -ForegroundColor White
Write-Host "  User: postgres" -ForegroundColor White
Write-Host "  Password: [senha do Supabase]" -ForegroundColor White
Write-Host ""
