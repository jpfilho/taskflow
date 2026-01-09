#!/bin/bash

# Script para executar NO SERVIDOR
# Configura o Nginx na porta 8080

echo "=========================================="
echo "Configurando Nginx na Porta 8080"
echo "=========================================="
echo ""

# Criar/atualizar configuração
echo "📝 Criando configuração para porta 8080..."
cat > /etc/nginx/sites-available/task2026 << 'EOF'
server {
    listen 8080;
    server_name 212.85.0.249;
    
    root /var/www/html/task2026;
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
    
    # Fallback para SPA (Single Page Application)
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

# Ativar site
echo ""
echo "🔗 Ativando site..."
ln -sf /etc/nginx/sites-available/task2026 /etc/nginx/sites-enabled/

# Remover site padrão (opcional)
rm -f /etc/nginx/sites-enabled/default

# Testar configuração
echo ""
echo "🧪 Testando configuração..."
nginx -t

if [ $? -eq 0 ]; then
    # Recarregar Nginx
    echo ""
    echo "🔄 Recarregando Nginx..."
    systemctl reload nginx
    
    # Verificar status
    echo ""
    echo "📊 Status do Nginx:"
    systemctl status nginx --no-pager | head -10
    
    # Verificar porta
    echo ""
    echo "🔍 Verificando porta 8080:"
    netstat -tulpn | grep :8080 || ss -tulpn | grep :8080
    
    echo ""
    echo "=========================================="
    echo "✅ Nginx configurado na porta 8080!"
    echo "=========================================="
    echo ""
    echo "🌐 Acesse a aplicação em:"
    echo "   http://212.85.0.249:8080/task2026/"
    echo ""
else
    echo ""
    echo "❌ Erro na configuração do Nginx!"
    echo "   Verifique os erros acima."
    echo ""
fi
