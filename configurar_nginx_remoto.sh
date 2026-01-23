#!/bin/bash

# Execute este script NO SERVIDOR (já conectado via SSH)
# Ou copie e cole os comandos abaixo diretamente no terminal do servidor

echo "=========================================="
echo "Configurando Nginx para /task2026/"
echo "=========================================="
echo ""

# Criar configuração correta
cat > /etc/nginx/sites-available/task2026 << 'EOF'
server {
    listen 8080;
    server_name 212.85.0.249;
    
    # Servir arquivos estáticos diretamente
    root /var/www/html;
    index index.html;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/wasm;
    
    # Cache para assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Rota específica para /task2026/
    location /task2026/ {
        alias /var/www/html/task2026/;
        try_files $uri $uri/ /task2026/index.html;
        
        # Headers para SPA
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
    
    # Redirecionar /task2026 para /task2026/
    location = /task2026 {
        return 301 /task2026/;
    }
    
    # Fallback para outras rotas (opcional)
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

# Ativar site
ln -sf /etc/nginx/sites-available/task2026 /etc/nginx/sites-enabled/

# Testar configuração
echo "🧪 Testando configuração..."
if nginx -t; then
    echo "✅ Configuração válida!"
    
    # Recarregar Nginx
    echo "🔄 Recarregando Nginx..."
    systemctl reload nginx
    
    echo ""
    echo "✅ Nginx configurado corretamente!"
    echo ""
    echo "🌐 Acesse a aplicação em:"
    echo "   http://212.85.0.249:8080/task2026/"
    echo ""
    echo "🧪 Testando acesso..."
    curl -I http://localhost:8080/task2026/ 2>&1 | head -5
else
    echo "❌ Erro na configuração!"
    exit 1
fi
