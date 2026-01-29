#!/bin/bash
# ============================================
# CONFIGURAR SSL PARA TELEGRAM
# ============================================

DOMINIO="api.taskflowv3.com.br"
EMAIL="filhocefet1@gmail.com"  # ALTERAR PARA SEU EMAIL

echo "=========================================="
echo "CONFIGURANDO SSL PARA TELEGRAM"
echo "=========================================="
echo ""

# 1. Instalar certbot se necessario
echo "1. Verificando certbot..."
if ! command -v certbot &> /dev/null; then
    echo "   Instalando certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
else
    echo "   Certbot ja instalado!"
fi

# 2. Parar nginx temporariamente
echo ""
echo "2. Parando Nginx temporariamente..."
systemctl stop nginx

# 3. Obter certificado
echo ""
echo "3. Obtendo certificado SSL para $DOMINIO..."
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    -d $DOMINIO

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ ERRO ao obter certificado!"
    echo "Verifique se:"
    echo "  - O dominio $DOMINIO resolve para este servidor"
    echo "  - A porta 80 esta acessivel externamente"
    systemctl start nginx
    exit 1
fi

# 4. Configurar Nginx para HTTPS
echo ""
echo "4. Configurando Nginx para HTTPS..."
cat > /etc/nginx/sites-available/supabase-ssl << 'EOFNGINX'
# Redirecionar HTTP para HTTPS
server {
    listen 80;
    server_name api.taskflowv3.com.br;
    return 301 https://$server_name$request_uri;
}

# HTTPS para Supabase
server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/api.taskflowv3.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflowv3.com.br/privkey.pem;
    
    # Configuracoes SSL recomendadas
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Proxy para Supabase
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Logs
    access_log /var/log/nginx/supabase_ssl_access.log;
    error_log /var/log/nginx/supabase_ssl_error.log;
}
EOFNGINX

# 5. Habilitar site
echo ""
echo "5. Habilitando site SSL..."
ln -sf /etc/nginx/sites-available/supabase-ssl /etc/nginx/sites-enabled/supabase-ssl

# 6. Testar configuracao
echo ""
echo "6. Testando configuracao do Nginx..."
nginx -t

if [ $? -eq 0 ]; then
    # 7. Iniciar Nginx
    echo ""
    echo "7. Iniciando Nginx..."
    systemctl start nginx
    
    # 8. Verificar se esta funcionando
    echo ""
    echo "8. Testando HTTPS..."
    sleep 2
    curl -I https://api.taskflowv3.com.br/ 2>/dev/null | head -5
    
    echo ""
    echo "=========================================="
    echo "✅ SSL CONFIGURADO COM SUCESSO!"
    echo "=========================================="
    echo ""
    echo "Teste: https://api.taskflowv3.com.br/"
    echo ""
    echo "Proximo passo: Configurar webhook do Telegram"
    echo "   URL: https://api.taskflowv3.com.br/functions/v1/telegram-webhook"
    echo ""
    
    # 9. Configurar renovacao automatica
    echo "9. Configurando renovacao automatica..."
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    echo "   Renovacao automatica configurada!"
    
else
    echo ""
    echo "❌ ERRO na configuracao do Nginx!"
    systemctl start nginx
    exit 1
fi
