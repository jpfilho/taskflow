# ============================================
# ADICIONAR LOCATION /telegram-webhook NO NGINX
# ============================================

$SERVER = "root@212.85.0.249"
$NGINX_CONFIG = "/etc/nginx/sites-enabled/supabase"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ADICIONAR /telegram-webhook NO NGINX" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se já existe
Write-Host "1. Verificando se location /telegram-webhook já existe..." -ForegroundColor Yellow
$checkCmd = "grep -q 'location /telegram-webhook' $NGINX_CONFIG && echo 'EXISTS' || echo 'NOT_EXISTS'"
$exists = ssh $SERVER $checkCmd

if ($exists -match "EXISTS") {
    Write-Host "   [OK] Location /telegram-webhook já existe!" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Mostrando configuração atual:" -ForegroundColor Gray
    ssh $SERVER "grep -A 10 'location /telegram-webhook' $NGINX_CONFIG"
    Write-Host ""
    Write-Host -NoNewline "   Deseja adicionar mesmo assim? (S/N): " -ForegroundColor Yellow
    $confirm = Read-Host
    if ($confirm -ne "S" -and $confirm -ne "s") {
        Write-Host "   Cancelado!" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "   [INFO] Location /telegram-webhook não encontrado" -ForegroundColor Yellow
    Write-Host "   Será adicionado agora..." -ForegroundColor Gray
}

Write-Host ""

# 2. Fazer backup
Write-Host "2. Fazendo backup do arquivo de configuração..." -ForegroundColor Yellow
$backupCmd = "cp $NGINX_CONFIG ${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
ssh $SERVER $backupCmd
Write-Host "   [OK] Backup criado" -ForegroundColor Green

Write-Host ""

# 3. Verificar onde adicionar (antes de /send-message ou no final do server block)
Write-Host "3. Verificando estrutura do arquivo..." -ForegroundColor Yellow
$structureCmd = "grep -n 'location /send-message\|location /' $NGINX_CONFIG | head -5"
$structure = ssh $SERVER $structureCmd
Write-Host "   Estrutura encontrada:" -ForegroundColor Gray
$structure | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }

Write-Host ""

# 4. Criar bloco de configuração
$nginxBlock = @"
    # Webhook do Telegram (recebe mensagens do Telegram)
    location /telegram-webhook {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        proxy_set_header x-telegram-bot-api-secret-token `$http_x_telegram_bot_api_secret_token;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
"@

# Salvar em arquivo temporário
$tempFile = "nginx_telegram_webhook_block.txt"
$nginxBlock | Out-File -FilePath $tempFile -Encoding UTF8

Write-Host "4. Adicionando location /telegram-webhook..." -ForegroundColor Yellow

# Estratégia: adicionar antes de /send-message se existir, senão antes do location / final
$addCmd = @"
if grep -q 'location /send-message' $NGINX_CONFIG; then
    # Adicionar antes de /send-message
    sed -i '/location \/send-message/i\
    # Webhook do Telegram (recebe mensagens do Telegram)\
    location /telegram-webhook {\
        proxy_pass http://127.0.0.1:3001;\
        proxy_http_version 1.1;\
        proxy_set_header Host \$host;\
        proxy_set_header X-Real-IP \$remote_addr;\
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto \$scheme;\
        proxy_set_header x-telegram-bot-api-secret-token \$http_x_telegram_bot_api_secret_token;\
        proxy_connect_timeout 60s;\
        proxy_send_timeout 60s;\
        proxy_read_timeout 60s;\
    }' $NGINX_CONFIG
else
    # Adicionar antes do último location / ou no final do server block
    sed -i '/^[[:space:]]*location \//a\
    # Webhook do Telegram (recebe mensagens do Telegram)\
    location /telegram-webhook {\
        proxy_pass http://127.0.0.1:3001;\
        proxy_http_version 1.1;\
        proxy_set_header Host \$host;\
        proxy_set_header X-Real-IP \$remote_addr;\
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto \$scheme;\
        proxy_set_header x-telegram-bot-api-secret-token \$http_x_telegram_bot_api_secret_token;\
        proxy_connect_timeout 60s;\
        proxy_send_timeout 60s;\
        proxy_read_timeout 60s;\
    }' $NGINX_CONFIG
fi
"@

# Usar método mais simples: criar arquivo Python temporário no servidor
$pythonScript = @"
import re

config_file = '$NGINX_CONFIG'
nginx_block = '''    # Webhook do Telegram (recebe mensagens do Telegram)
    location /telegram-webhook {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        proxy_set_header x-telegram-bot-api-secret-token `$http_x_telegram_bot_api_secret_token;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
'''

with open(config_file, 'r') as f:
    content = f.read()

# Verificar se já existe
if 'location /telegram-webhook' in content:
    print('JÁ_EXISTE')
    exit(0)

# Adicionar antes de /send-message se existir
if 'location /send-message' in content:
    content = content.replace('location /send-message', nginx_block + '\n    location /send-message')
else:
    # Adicionar antes do último location / ou no final do server block
    # Encontrar último location / antes do fechamento do server block
    pattern = r'(location /[^{]*\{[^}]*\})'
    matches = list(re.finditer(pattern, content))
    if matches:
        last_match = matches[-1]
        insert_pos = last_match.end()
        content = content[:insert_pos] + '\n' + nginx_block + content[insert_pos:]
    else:
        # Adicionar antes do fechamento do server block
        content = content.replace('}', nginx_block + '\n    }', 1)

with open(config_file, 'w') as f:
    f.write(content)

print('ADICIONADO')
"@

$pythonFile = "add_telegram_webhook.py"
$pythonScript | Out-File -FilePath $pythonFile -Encoding UTF8

# Copiar e executar no servidor
scp $pythonFile "${SERVER}:/tmp/"
$result = ssh $SERVER "python3 /tmp/$pythonFile"

if ($result -match "JÁ_EXISTE") {
    Write-Host "   [INFO] Location já existe, pulando..." -ForegroundColor Yellow
} elseif ($result -match "ADICIONADO") {
    Write-Host "   [OK] Location /telegram-webhook adicionado!" -ForegroundColor Green
} else {
    Write-Host "   [ERRO] Falha ao adicionar: $result" -ForegroundColor Red
    Write-Host "   Tentando método alternativo (sed)..." -ForegroundColor Yellow
    
    # Método alternativo: usar sed simples
    $sedCmd = "sed -i '/location \/send-message/i\    # Webhook do Telegram\n    location /telegram-webhook {\n        proxy_pass http://127.0.0.1:3001;\n        proxy_http_version 1.1;\n        proxy_set_header Host `$host;\n        proxy_set_header X-Real-IP `$remote_addr;\n        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto `$scheme;\n        proxy_set_header x-telegram-bot-api-secret-token `$http_x_telegram_bot_api_secret_token;\n        proxy_connect_timeout 60s;\n        proxy_send_timeout 60s;\n        proxy_read_timeout 60s;\n    }' $NGINX_CONFIG"
    ssh $SERVER $sedCmd
}

# Limpar arquivo temporário
Remove-Item $pythonFile -ErrorAction SilentlyContinue
Remove-Item $tempFile -ErrorAction SilentlyContinue
ssh $SERVER "rm -f /tmp/$pythonFile" 2>&1 | Out-Null

Write-Host ""

# 5. Testar configuração
Write-Host "5. Testando configuração do Nginx..." -ForegroundColor Yellow
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

# 6. Recarregar Nginx
Write-Host "6. Recarregando Nginx..." -ForegroundColor Yellow
ssh $SERVER "systemctl reload nginx"
Write-Host "   [OK] Nginx recarregado!" -ForegroundColor Green

Write-Host ""

# 7. Verificar configuração final
Write-Host "7. Verificando configuração final..." -ForegroundColor Yellow
ssh $SERVER "grep -A 10 'location /telegram-webhook' $NGINX_CONFIG"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "CONFIGURAÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "1. Configure o webhook no Telegram:" -ForegroundColor Yellow
Write-Host "   .\configurar_webhook_nodejs.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Monitore os logs:" -ForegroundColor Yellow
Write-Host "   ssh $SERVER 'journalctl -u telegram-webhook -f'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Envie uma mensagem no Telegram e verifique se aparece 'Update recebido'" -ForegroundColor Yellow
Write-Host ""
