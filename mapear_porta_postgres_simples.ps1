# Script SIMPLES para mapear porta do Postgres Supabase
# Servidor: 212.85.0.249

$SERVER_IP = "212.85.0.249"
$SERVER_USER = "root"
$CONTAINER_NAME = "supabase-db"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Mapear Porta Postgres - Versão Simples" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Encontrar docker-compose.yml
Write-Host "[1/4] Procurando docker-compose.yml..." -ForegroundColor Yellow
$composePath = ssh ${SERVER_USER}@${SERVER_IP} "find /opt /home /root -name 'docker-compose.yml' 2>/dev/null | xargs grep -l 'supabase-db' 2>/dev/null | head -1"
if (-not $composePath) {
    $composePath = ssh ${SERVER_USER}@${SERVER_IP} "find /opt/supabase /root/supabase -name 'docker-compose.yml' 2>/dev/null | head -1"
}

if (-not $composePath) {
    Write-Host "❌ docker-compose.yml não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUÇÃO MANUAL:" -ForegroundColor Yellow
    Write-Host "1. Acesse: ssh root@212.85.0.249" -ForegroundColor White
    Write-Host "2. Encontre o docker-compose.yml do Supabase" -ForegroundColor White
    Write-Host "3. Adicione na seção supabase-db:" -ForegroundColor White
    Write-Host "   ports:" -ForegroundColor Gray
    Write-Host "     - `"5432:5432`"" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Encontrado: $composePath" -ForegroundColor Green

# 2. Verificar se já está mapeado
Write-Host ""
Write-Host "[2/4] Verificando se porta já está mapeada..." -ForegroundColor Yellow
$hasMapping = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 10 'supabase-db:' $composePath | grep '5432:5432'"
if ($hasMapping) {
    Write-Host "✅ Porta já está mapeada!" -ForegroundColor Green
    Write-Host "Reiniciando container..." -ForegroundColor Yellow
    $composeDir = ssh ${SERVER_USER}@${SERVER_IP} "dirname $composePath"
    ssh ${SERVER_USER}@${SERVER_IP} "cd $composeDir && docker-compose restart $CONTAINER_NAME"
    Write-Host "✅ Pronto!" -ForegroundColor Green
    exit 0
}

# 3. Fazer backup
Write-Host ""
Write-Host "[3/4] Fazendo backup..." -ForegroundColor Yellow
$backupFile = "$composePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
ssh ${SERVER_USER}@${SERVER_IP} "cp $composePath $backupFile"
Write-Host "✅ Backup: $backupFile" -ForegroundColor Green

# 4. Adicionar mapeamento (método simples: inserir após supabase-db:)
Write-Host ""
Write-Host "[4/4] Adicionando mapeamento de porta..." -ForegroundColor Yellow

# Criar script Python para adicionar mapeamento de forma segura
$addPortScript = @"
#!/usr/bin/env python3
import sys
import re

compose_file = sys.argv[1]

with open(compose_file, 'r') as f:
    lines = f.readlines()

new_lines = []
in_supabase_db = False
ports_added = False
indent_level = 0

for i, line in enumerate(lines):
    # Detectar início da seção supabase-db
    if re.match(r'^\s*supabase-db:', line):
        in_supabase_db = True
        indent_level = len(line) - len(line.lstrip())
        new_lines.append(line)
        # Adicionar ports logo após supabase-db: se não existe
        if i + 1 < len(lines):
            next_line = lines[i + 1]
            # Se próxima linha não é ports:, adicionar
            if 'ports:' not in next_line.lower():
                new_lines.append(' ' * (indent_level + 2) + 'ports:\n')
                new_lines.append(' ' * (indent_level + 4) + '- "5432:5432"\n')
                ports_added = True
        else:
            # Última linha do arquivo
            new_lines.append(' ' * (indent_level + 2) + 'ports:\n')
            new_lines.append(' ' * (indent_level + 4) + '- "5432:5432"\n')
            ports_added = True
        continue
    
    # Se estamos na seção supabase-db
    if in_supabase_db:
        # Verificar se já tem ports: e 5432:5432
        if 'ports:' in line.lower():
            new_lines.append(line)
            # Verificar próxima linha
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                if '5432:5432' in next_line:
                    ports_added = True
                    new_lines.append(next_line)
                    # Pular próxima linha na próxima iteração
                    continue
                elif not re.match(r'^\s+-', next_line):
                    new_lines.append(' ' * (indent_level + 4) + '- "5432:5432"\n')
                    ports_added = True
            else:
                new_lines.append(' ' * (indent_level + 4) + '- "5432:5432"\n')
                ports_added = True
            continue
        
        # Verificar se saímos da seção (nova seção no mesmo nível)
        current_indent = len(line) - len(line.lstrip()) if line.strip() else indent_level + 1
        if line.strip() and current_indent <= indent_level and not line.strip().startswith('#'):
            # Sair da seção, adicionar ports antes se não foi adicionado
            if not ports_added:
                new_lines.append(' ' * (indent_level + 2) + 'ports:\n')
                new_lines.append(' ' * (indent_level + 4) + '- "5432:5432"\n')
                ports_added = True
            in_supabase_db = False
            new_lines.append(line)
            continue
    
    new_lines.append(line)

# Se ainda não adicionou e estamos na seção, adicionar no final
if in_supabase_db and not ports_added:
    new_lines.append(' ' * (indent_level + 2) + 'ports:\n')
    new_lines.append(' ' * (indent_level + 4) + '- "5432:5432"\n')

# Escrever arquivo
with open(compose_file, 'w') as f:
    f.writelines(new_lines)

print("Mapeamento adicionado com sucesso!")
"@

# Salvar e executar script Python
$tempScript = "/tmp/add_port.py"
$addPortScript | ssh ${SERVER_USER}@${SERVER_IP} "cat > $tempScript && chmod +x $tempScript"
$result = ssh ${SERVER_USER}@${SERVER_IP} "python3 $tempScript $composePath 2>&1"
Write-Host $result -ForegroundColor Gray

# Limpar script temporário
ssh ${SERVER_USER}@${SERVER_IP} "rm -f $tempScript"

# Verificar se foi adicionado - mostrar seção completa primeiro
Write-Host ""
Write-Host "Verificando seção supabase-db após modificação..." -ForegroundColor Yellow
$sectionContent = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 20 'supabase-db:' $composePath | head -25"
Write-Host $sectionContent -ForegroundColor Gray

# Verificar se tem mapeamento (verificação mais flexível)
$verify1 = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 20 'supabase-db:' $composePath | grep '5432:5432'"
$verify2 = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 20 'supabase-db:' $composePath | grep 'ports:'"
$verify3 = ssh ${SERVER_USER}@${SERVER_IP} "grep '5432:5432' $composePath"

if ($verify1 -or $verify3) {
    Write-Host "✅ Mapeamento encontrado!" -ForegroundColor Green
    if ($verify1) { Write-Host $verify1 -ForegroundColor Gray }
    if ($verify3) { Write-Host "Linha com mapeamento: $verify3" -ForegroundColor Gray }
    
    # Reiniciar container
    Write-Host ""
    Write-Host "Reiniciando container..." -ForegroundColor Yellow
    $composeDir = ssh ${SERVER_USER}@${SERVER_IP} "dirname $composePath"
    ssh ${SERVER_USER}@${SERVER_IP} "cd $composeDir && docker-compose up -d $CONTAINER_NAME"
    
    Start-Sleep -Seconds 3
    
    # Verificar porta
    $portCheck = ssh ${SERVER_USER}@${SERVER_IP} "docker port $CONTAINER_NAME 5432 2>&1"
    if ($portCheck -match "5432") {
        Write-Host "✅ Porta mapeada e container reiniciado!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Verifique manualmente: docker port $CONTAINER_NAME" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Mapeamento pode não ter sido adicionado corretamente" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Verificando conteúdo do arquivo..." -ForegroundColor Yellow
    $fileCheck = ssh ${SERVER_USER}@${SERVER_IP} "grep -n 'supabase-db:' $composePath"
    Write-Host "Linha encontrada: $fileCheck" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Tentando método alternativo..." -ForegroundColor Yellow
    # Tentar adicionar manualmente usando echo
    $manualAdd = ssh ${SERVER_USER}@${SERVER_IP} "bash -c `"sed -i '/supabase-db:/a\\  ports:\\n    - \\\"5432:5432\\\"' $composePath && echo 'Adicionado via sed'`""
    Write-Host $manualAdd -ForegroundColor Gray
    
    # Verificar novamente
    Start-Sleep -Seconds 1
    $finalCheck = ssh ${SERVER_USER}@${SERVER_IP} "grep -A 10 'supabase-db:' $composePath | grep '5432:5432'"
    if ($finalCheck) {
        Write-Host "✅ Mapeamento adicionado via método alternativo!" -ForegroundColor Green
    } else {
        Write-Host "❌ Não foi possível adicionar automaticamente" -ForegroundColor Red
        Write-Host "Restaurando backup..." -ForegroundColor Yellow
        ssh ${SERVER_USER}@${SERVER_IP} "cp $backupFile $composePath"
        Write-Host ""
        Write-Host "SOLUÇÃO MANUAL:" -ForegroundColor Yellow
        Write-Host "1. Acesse: ssh root@212.85.0.249" -ForegroundColor White
        Write-Host "2. Edite: $composePath" -ForegroundColor White
        Write-Host "3. Na seção 'supabase-db:', adicione:" -ForegroundColor White
        Write-Host "   ports:" -ForegroundColor Gray
        Write-Host "     - `"5432:5432`"" -ForegroundColor Gray
        Write-Host "4. Salve e execute: docker-compose up -d supabase-db" -ForegroundColor White
        exit 1
    }
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
