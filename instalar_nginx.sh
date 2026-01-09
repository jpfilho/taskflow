#!/bin/bash

# Script para executar NO SERVIDOR
# Instala e configura o Nginx

echo "=========================================="
echo "Instalando e Configurando Nginx"
echo "=========================================="
echo ""

# Instalar Nginx
echo "📦 Instalando Nginx..."
apt update
apt install -y nginx

# Iniciar e habilitar Nginx
echo ""
echo "🚀 Iniciando Nginx..."
systemctl start nginx
systemctl enable nginx

# Verificar status
echo ""
echo "📊 Status do Nginx:"
systemctl status nginx --no-pager | head -5

# Criar configuração
echo ""
echo "📝 Criando configuração..."
cat > /etc/nginx/sites-available/task2026 << 'EOF'
server {
    listen 80;
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

# Recarregar Nginx
echo ""
echo "🔄 Recarregando Nginx..."
systemctl reload nginx

# Ajustar permissões
echo ""
echo "🔐 Ajustando permissões..."
chown -R www-data:www-data /var/www/html/task2026
chmod -R 755 /var/www/html/task2026

echo ""
echo "=========================================="
echo "✅ Nginx instalado e configurado!"
echo "=========================================="
echo ""
echo "🌐 Acesse a aplicação em:"
echo "   http://212.85.0.249/task2026/"
echo ""
echo "📋 Verificar status:"
echo "   systemctl status nginx"
echo ""
