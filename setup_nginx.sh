#!/bin/bash
# ============================================
# CONFIGURAR NGINX
# ============================================

cat > /etc/nginx/sites-available/supabase-ssl << 'EOF'
server {
    listen 80;
    server_name api.taskflowv3.com.br;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.taskflowv3.com.br;
    
    ssl_certificate /etc/letsencrypt/live/api.taskflowv3.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflowv3.com.br/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    client_max_body_size 50M;
    
    location /telegram-webhook {
        proxy_pass http://127.0.0.1:3001/telegram-webhook;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header x-telegram-bot-api-secret-token $http_x_telegram_bot_api_secret_token;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_buffering off;
    }
    
    access_log /var/log/nginx/supabase_ssl_access.log;
    error_log /var/log/nginx/supabase_ssl_error.log;
}
EOF

nginx -t && systemctl reload nginx

echo "Nginx configurado!"
