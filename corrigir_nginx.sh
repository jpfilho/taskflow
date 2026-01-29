#!/bin/bash
# ============================================
# CORRIGIR CONFIGURACAO DO NGINX NO SERVIDOR
# ============================================

echo "=========================================="
echo "CORRIGINDO NGINX TASK2026"
echo "=========================================="
echo ""

# Fazer backup
echo "1. Fazendo backup da configuracao atual..."
cp /etc/nginx/sites-available/task2026 /etc/nginx/sites-available/task2026.backup.$(date +%Y%m%d_%H%M%S)

# Criar nova configuracao
echo "2. Criando nova configuracao..."
cat > /etc/nginx/sites-available/task2026 << 'EOFCONFIG'
server {
    listen 8080;
    listen [::]:8080;
    
    server_name 212.85.0.249 taskflowv3.com.br www.taskflowv3.com.br;
    
    root /var/www/html;
    index index.html;
    
    # Compressao
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/wasm;
    
    # Cache para assets estaticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Rota especifica para /task2026/
    location /task2026/ {
        alias /var/www/html/task2026/;
        try_files $uri $uri/ /task2026/index.html;
        
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
    
    # Redirecionar /task2026 para /task2026/
    location = /task2026 {
        return 301 /task2026/;
    }
    
    # Fallback para outras rotas
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Logs
    access_log /var/log/nginx/task2026_access.log;
    error_log /var/log/nginx/task2026_error.log;
}
EOFCONFIG

# Testar configuracao
echo ""
echo "3. Testando configuracao..."
nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "4. Recarregando Nginx..."
    systemctl reload nginx
    
    echo ""
    echo "5. Verificando status..."
    systemctl status nginx --no-pager | head -10
    
    echo ""
    echo "6. Testando acesso local..."
    curl -I http://localhost:8080/task2026/ 2>/dev/null | head -10
    
    echo ""
    echo "=========================================="
    echo "✅ NGINX CORRIGIDO COM SUCESSO!"
    echo "=========================================="
    echo ""
    echo "Teste no navegador:"
    echo "   http://212.85.0.249:8080/task2026/"
    echo ""
else
    echo ""
    echo "❌ ERRO na configuracao do Nginx!"
    echo "Restaurando backup..."
    cp /etc/nginx/sites-available/task2026.backup.* /etc/nginx/sites-available/task2026
    exit 1
fi
