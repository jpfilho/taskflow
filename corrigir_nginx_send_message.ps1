# ============================================
# CORRIGIR NGINX PARA /send-message
# ============================================
# Este script configura o Nginx para permitir
# o endpoint /send-message do Telegram

$SERVER = "root@212.85.0.249"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CORRIGINDO NGINX PARA /send-message" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar configuração atual do Nginx
Write-Host "1. Verificando configuração atual do Nginx..." -ForegroundColor Yellow
$nginxConfig = ssh $SERVER "cat /etc/nginx/sites-enabled/supabase-ssl 2>/dev/null || cat /etc/nginx/sites-enabled/default 2>/dev/null || echo 'Nenhuma config encontrada'"
if ($nginxConfig -match "location.*send-message") {
    Write-Host "   [AVISO] Já existe configuração para /send-message" -ForegroundColor Yellow
    Write-Host "   Verificando se está correta..." -ForegroundColor Gray
} else {
    Write-Host "   [INFO] Nenhuma configuração específica para /send-message encontrada" -ForegroundColor Yellow
}

# 2. Verificar se há proxy_pass para porta 3001
Write-Host ""
Write-Host "2. Verificando se Nginx faz proxy para porta 3001..." -ForegroundColor Yellow
$proxyCheck = ssh $SERVER "grep -r 'proxy_pass.*3001' /etc/nginx/sites-enabled/ 2>/dev/null || echo 'Nenhum proxy para 3001'"
if ($proxyCheck -match "3001") {
    Write-Host "   [OK] Nginx já faz proxy para porta 3001" -ForegroundColor Green
} else {
    Write-Host "   [AVISO] Nginx não faz proxy para porta 3001" -ForegroundColor Yellow
}

# 3. Criar/atualizar configuração do Nginx
Write-Host ""
Write-Host "3. Configurando Nginx para /send-message..." -ForegroundColor Yellow

$nginxConfigScript = @"
#!/bin/bash
# Backup da configuração atual
if [ -f /etc/nginx/sites-enabled/supabase-ssl ]; then
    cp /etc/nginx/sites-enabled/supabase-ssl /etc/nginx/sites-enabled/supabase-ssl.backup.\$(date +%Y%m%d_%H%M%S)
    CONFIG_FILE="/etc/nginx/sites-enabled/supabase-ssl"
elif [ -f /etc/nginx/sites-enabled/default ]; then
    cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup.\$(date +%Y%m%d_%H%M%S)
    CONFIG_FILE="/etc/nginx/sites-enabled/default"
else
    CONFIG_FILE="/etc/nginx/sites-available/supabase-ssl"
fi

# Verificar se já existe location /send-message
if grep -q "location.*send-message" \$CONFIG_FILE 2>/dev/null; then
    echo "⚠️  Já existe configuração para /send-message"
    echo "   Removendo configuração antiga..."
    # Remover configuração antiga (linhas entre location /send-message e a próxima location ou }
    sed -i '/location.*send-message/,/^[[:space:]]*}/d' \$CONFIG_FILE
fi

# Adicionar configuração para /send-message ANTES do location /
# Isso garante que /send-message seja processado primeiro
if [ -f \$CONFIG_FILE ]; then
    # Encontrar a linha do "location /" no bloco HTTPS (443)
    if grep -q "listen 443" \$CONFIG_FILE; then
        # Inserir antes do "location /" no bloco HTTPS
        sed -i '/listen 443/,/location \// {
            /location \// i\
    # Proxy para Telegram webhook (Node.js porta 3001)\
    location /send-message {\
        proxy_pass http://127.0.0.1:3001;\
        proxy_http_version 1.1;\
        proxy_set_header Host \$host;\
        proxy_set_header X-Real-IP \$remote_addr;\
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto \$scheme;\
        proxy_set_header Content-Type application/json;\
        \
        # Timeouts aumentados para uploads\
        proxy_connect_timeout 60s;\
        proxy_send_timeout 60s;\
        proxy_read_timeout 60s;\
        \
        # Permitir CORS (se necessário)\
        add_header Access-Control-Allow-Origin * always;\
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;\
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;\
        \
        # Tratar OPTIONS (preflight)\
        if (\$request_method = OPTIONS) {\
            return 204;\
        }\
    }
        }' \$CONFIG_FILE
    fi
else
    echo "❌ Arquivo de configuração não encontrado: \$CONFIG_FILE"
    exit 1
fi

# Testar configuração
echo ""
echo "🧪 Testando configuração do Nginx..."
nginx -t

if [ \$? -eq 0 ]; then
    echo "✅ Configuração válida!"
    echo ""
    echo "🔄 Recarregando Nginx..."
    systemctl reload nginx
    echo "✅ Nginx recarregado!"
else
    echo "❌ Erro na configuração do Nginx!"
    echo "   Restaurando backup..."
    # Restaurar último backup
    LATEST_BACKUP=\$(ls -t \$CONFIG_FILE.backup.* 2>/dev/null | head -1)
    if [ -n "\$LATEST_BACKUP" ]; then
        cp "\$LATEST_BACKUP" "\$CONFIG_FILE"
        nginx -t && systemctl reload nginx
        echo "✅ Backup restaurado"
    fi
    exit 1
fi
"@

# Salvar script temporariamente no servidor
Write-Host "   Enviando script de configuração..." -ForegroundColor Gray
ssh $SERVER "cat > /tmp/configurar_nginx_send_message.sh << 'EOFBASH'
$nginxConfigScript
EOFBASH
chmod +x /tmp/configurar_nginx_send_message.sh"

# Executar script
Write-Host "   Executando configuração..." -ForegroundColor Gray
$result = ssh $SERVER "/tmp/configurar_nginx_send_message.sh 2>&1"

if ($result -match "Configuração válida|Nginx recarregado") {
    Write-Host "   [OK] Nginx configurado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "   [ERRO] Falha ao configurar Nginx" -ForegroundColor Red
    Write-Host "   Saída: $result" -ForegroundColor Gray
}

# 4. Verificar se porta 3001 está acessível externamente
Write-Host ""
Write-Host "4. Verificando se porta 3001 está acessível..." -ForegroundColor Yellow
$firewallCheck = ssh $SERVER "ufw status 2>&1 | head -5"
if ($firewallCheck -match "Status: active") {
    $port3001Check = ssh $SERVER "ufw status | grep 3001"
    if (-not $port3001Check) {
        Write-Host "   [AVISO] Porta 3001 não está liberada no firewall" -ForegroundColor Yellow
        Write-Host "   Liberando porta 3001..." -ForegroundColor Gray
        ssh $SERVER "ufw allow 3001/tcp comment 'Telegram webhook HTTP fallback'" | Out-Null
        Write-Host "   [OK] Porta 3001 liberada" -ForegroundColor Green
    } else {
        Write-Host "   [OK] Porta 3001 já está liberada" -ForegroundColor Green
    }
} else {
    Write-Host "   [OK] Firewall não está ativo" -ForegroundColor Green
}

# 5. Verificar se Node.js está escutando em 0.0.0.0
Write-Host ""
Write-Host "5. Verificando se Node.js escuta em todas as interfaces..." -ForegroundColor Yellow
$nodeListen = ssh $SERVER "netstat -tlnp 2>/dev/null | grep :3001 || ss -tlnp 2>/dev/null | grep :3001"
if ($nodeListen -match "0\.0\.0\.0:3001|:::3001") {
    Write-Host "   [OK] Node.js está escutando em todas as interfaces" -ForegroundColor Green
} elseif ($nodeListen -match "127\.0\.0\.1:3001") {
    Write-Host "   [AVISO] Node.js está escutando apenas em localhost" -ForegroundColor Yellow
    Write-Host "   Isso pode impedir conexões externas diretas" -ForegroundColor Yellow
    Write-Host "   Nota: Nginx pode fazer proxy mesmo assim" -ForegroundColor Gray
} else {
    Write-Host "   [ERRO] Não foi possível verificar" -ForegroundColor Red
}

# 6. Testar endpoints
Write-Host ""
Write-Host "6. Testando endpoints..." -ForegroundColor Yellow

# Teste HTTPS via Nginx
Write-Host "   Testando HTTPS via Nginx..." -ForegroundColor Gray
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $body = @{mensagem_id="test"; thread_type="TASK"; thread_id="test"} | ConvertTo-Json
    $response = Invoke-WebRequest -Uri "https://api.taskflowv3.com.br/send-message" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
    Write-Host "   [OK] HTTPS via Nginx funciona! Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "   [AVISO] Endpoint retornou 404 - pode ser que a mensagem 'test' não exista (esperado)" -ForegroundColor Yellow
    } elseif ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Write-Host "   [ERRO] Ainda retorna 401 - verifique configuração do Nginx" -ForegroundColor Red
    } else {
        Write-Host "   [ERRO] Erro: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Resumo
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RESUMO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuração do Nginx atualizada para permitir /send-message" -ForegroundColor White
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "1. Teste novamente: .\testar_servidor_telegram_rapido.ps1" -ForegroundColor White
Write-Host "2. Se ainda houver erro 401, verifique logs: ssh $SERVER 'tail -f /var/log/nginx/error.log'" -ForegroundColor White
Write-Host "3. Verifique se o Node.js está rodando: ssh $SERVER 'systemctl status telegram-webhook'" -ForegroundColor White
Write-Host ""
