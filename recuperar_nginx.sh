#!/bin/bash
# ============================================
# RECUPERAR NGINX - CONFIGURACAO SIMPLES
# ============================================

echo "=========================================="
echo "RECUPERANDO NGINX"
echo "=========================================="
echo ""

echo "1. Criando configuracao correta..."
cat > /etc/nginx/sites-available/task2026 << 'EOF'
server {
    listen 8080;
    listen [::]:8080;
    
    server_name 212.85.0.249 taskflowv3.com.br www.taskflowv3.com.br;
    
    # Rota para /task2026/
    location /task2026/ {
        alias /var/www/html/task2026/;
        index index.html;
        try_files $uri $uri/ /task2026/index.html;
    }
    
    # Redirecionar /task2026 para /task2026/
    location = /task2026 {
        return 301 /task2026/;
    }
    
    # Rota raiz
    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF

echo ""
echo "2. Testando configuracao..."
nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "3. Reiniciando Nginx..."
    systemctl restart nginx
    
    sleep 2
    
    echo ""
    echo "4. Verificando status..."
    systemctl status nginx --no-pager | head -10
    
    echo ""
    echo "5. Testando acesso..."
    curl -I http://localhost:8080/task2026/ 2>/dev/null | head -15
    
    echo ""
    echo "=========================================="
    echo "✅ NGINX RECUPERADO!"
    echo "=========================================="
    echo ""
    echo "Teste: http://212.85.0.249:8080/task2026/"
    echo ""
else
    echo ""
    echo "❌ ERRO na configuracao!"
    nginx -t
    exit 1
fi
