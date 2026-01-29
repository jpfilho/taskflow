# ============================================
# ADICIONAR LOCATION /delete-message NO NGINX
# ============================================

$SERVER = "root@212.85.0.249"
$NGINX_CONFIG = "/etc/nginx/sites-enabled/supabase"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ADICIONAR /delete-message NO NGINX" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se já existe
Write-Host "1. Verificando se location /delete-message já existe..." -ForegroundColor Yellow
$checkCmd = "grep -q 'location /delete-message' $NGINX_CONFIG && echo 'EXISTS' || echo 'NOT_EXISTS'"
$exists = ssh $SERVER $checkCmd

if ($exists -match "EXISTS") {
    Write-Host "   [OK] Location /delete-message já existe!" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Mostrando configuração atual:" -ForegroundColor Gray
    ssh $SERVER "grep -A 10 'location /delete-message' $NGINX_CONFIG"
    Write-Host ""
    Write-Host -NoNewline "   Deseja adicionar mesmo assim? (S/N): " -ForegroundColor Yellow
    $confirm = Read-Host
    if ($confirm -ne "S" -and $confirm -ne "s") {
        Write-Host "   Cancelado!" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "   [INFO] Location /delete-message não encontrado" -ForegroundColor Yellow
    Write-Host "   Será adicionado agora..." -ForegroundColor Gray
}

Write-Host ""

# 2. Fazer backup
Write-Host "2. Fazendo backup do arquivo de configuração..." -ForegroundColor Yellow
$backupCmd = "cp $NGINX_CONFIG ${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
ssh $SERVER $backupCmd
Write-Host "   [OK] Backup criado" -ForegroundColor Green

Write-Host ""

# 3. Adicionar location usando sed
Write-Host "3. Adicionando location /delete-message..." -ForegroundColor Yellow

# Adicionar antes de /send-message se existir, senão antes de /telegram-webhook
$addCmd = @"
if grep -q 'location /send-message' $NGINX_CONFIG; then
    sed -i '/location \/send-message/i\
    # Endpoint para deletar mensagens (Flutter → Telegram)\
    location /delete-message {\
        proxy_pass http://127.0.0.1:3001;\
        proxy_http_version 1.1;\
        proxy_set_header Host `$host;\
        proxy_set_header X-Real-IP `$remote_addr;\
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto `$scheme;\
        proxy_connect_timeout 60s;\
        proxy_send_timeout 60s;\
        proxy_read_timeout 60s;\
    }' $NGINX_CONFIG
elif grep -q 'location /telegram-webhook' $NGINX_CONFIG; then
    sed -i '/location \/telegram-webhook/i\
    # Endpoint para deletar mensagens (Flutter → Telegram)\
    location /delete-message {\
        proxy_pass http://127.0.0.1:3001;\
        proxy_http_version 1.1;\
        proxy_set_header Host `$host;\
        proxy_set_header X-Real-IP `$remote_addr;\
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto `$scheme;\
        proxy_connect_timeout 60s;\
        proxy_send_timeout 60s;\
        proxy_read_timeout 60s;\
    }' $NGINX_CONFIG
else
    echo "ERRO: Não encontrei location /send-message ou /telegram-webhook para referência"
    exit 1
fi
"@

$result = ssh $SERVER $addCmd 2>&1

if ($LASTEXITCODE -eq 0 -or $result -match "ERRO" -eq $false) {
    Write-Host "   [OK] Location /delete-message adicionado!" -ForegroundColor Green
} else {
    Write-Host "   [ERRO] Falha ao adicionar: $result" -ForegroundColor Red
    Write-Host "   Tentando método alternativo..." -ForegroundColor Yellow
    
    # Método alternativo: usar Python
    $pythonScript = @"
import re

config_file = '$NGINX_CONFIG'
nginx_block = '''    # Endpoint para deletar mensagens (Flutter → Telegram)
    location /delete-message {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
'''

with open(config_file, 'r') as f:
    content = f.read()

# Verificar se já existe
if 'location /delete-message' in content:
    print('JÁ_EXISTE')
    exit(0)

# Adicionar antes de /send-message se existir
if 'location /send-message' in content:
    content = content.replace('location /send-message', nginx_block + '\n    location /send-message')
elif 'location /telegram-webhook' in content:
    content = content.replace('location /telegram-webhook', nginx_block + '\n    location /telegram-webhook')
else:
    print('ERRO: Não encontrei referência')
    exit(1)

with open(config_file, 'w') as f:
    f.write(content)

print('ADICIONADO')
"@

    $pythonFile = "add_delete_message.py"
    $pythonScript | Out-File -FilePath $pythonFile -Encoding UTF8
    scp $pythonFile "${SERVER}:/tmp/"
    $pythonResult = ssh $SERVER "python3 /tmp/$pythonFile"
    Remove-Item $pythonFile -ErrorAction SilentlyContinue
    ssh $SERVER "rm -f /tmp/$pythonFile" 2>&1 | Out-Null
    
    if ($pythonResult -match "ADICIONADO") {
        Write-Host "   [OK] Location adicionado via Python!" -ForegroundColor Green
    } else {
        Write-Host "   [ERRO] Falha: $pythonResult" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# 4. Testar configuração
Write-Host "4. Testando configuração do Nginx..." -ForegroundColor Yellow
$testResult = ssh $SERVER "nginx -t" 2>&1

if ($testResult -match "successful") {
    Write-Host "   [OK] Configuração do Nginx está válida!" -ForegroundColor Green
} else {
    Write-Host "   [ERRO] Configuração do Nginx tem erros:" -ForegroundColor Red
    $testResult | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "   Restaurando backup..." -ForegroundColor Yellow
    ssh $SERVER "cp ${NGINX_CONFIG}.backup.* $NGINX_CONFIG" 2>&1 | Out-Null
    exit 1
}

Write-Host ""

# 5. Recarregar Nginx
Write-Host "5. Recarregando Nginx..." -ForegroundColor Yellow
ssh $SERVER "systemctl reload nginx"
Write-Host "   [OK] Nginx recarregado!" -ForegroundColor Green

Write-Host ""

# 6. Verificar configuração final
Write-Host "6. Verificando configuração final..." -ForegroundColor Yellow
ssh $SERVER "grep -A 10 'location /delete-message' $NGINX_CONFIG"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CONFIGURAÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "1. Teste deletar uma mensagem no Flutter" -ForegroundColor Yellow
Write-Host "2. Verifique se foi deletada no Telegram" -ForegroundColor Yellow
Write-Host "3. Monitore os logs:" -ForegroundColor Yellow
Write-Host "   ssh $SERVER 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
Write-Host "NOTA: Deletar no Telegram não sincroniza automaticamente" -ForegroundColor Yellow
Write-Host "      (limitação da Bot API do Telegram)" -ForegroundColor Gray
Write-Host ""
