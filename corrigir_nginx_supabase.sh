#!/bin/bash
# ============================================
# CORRIGIR NGINX PARA SUPABASE VIA HTTPS
# ============================================

echo "=========================================="
echo "CORRIGINDO PROXY NGINX PARA SUPABASE"
echo "=========================================="
echo ""

echo "1. Criando configuracao correta do Nginx..."
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
    
    # Configuracoes SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Tamanho maximo de upload
    client_max_body_size 50M;
    
    # Proxy para Supabase Kong (porta 8000)
    location / {
        # Headers importantes para Supabase
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port 443;
        
        # Headers necessarios para autenticacao Supabase
        proxy_set_header apikey $http_apikey;
        proxy_set_header Authorization $http_authorization;
        
        # WebSocket support (para Realtime)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts aumentados
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # Desabilitar buffering para streaming
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Logs
    access_log /var/log/nginx/supabase_ssl_access.log;
    error_log /var/log/nginx/supabase_ssl_error.log;
}
EOFNGINX

echo ""
echo "2. Testando configuracao..."
nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "3. Recarregando Nginx..."
    systemctl reload nginx
    
    echo ""
    echo "4. Testando acesso..."
    sleep 2
    curl -I https://api.taskflowv3.com.br/ 2>/dev/null | head -10
    
    echo ""
    echo "=========================================="
    echo "✅ NGINX CORRIGIDO!"
    echo "=========================================="
    echo ""
    echo "Teste agora:"
    echo "   https://api.taskflowv3.com.br/"
    echo ""
else
    echo ""
    echo "❌ ERRO na configuracao do Nginx!"
    exit 1
fi
