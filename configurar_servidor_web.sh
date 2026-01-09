#!/bin/bash

# Script para executar NO SERVIDOR
# Configura o servidor web para servir a aplicação Flutter

REMOTE_PATH="/var/www/html/task2026"

echo "=========================================="
echo "Configurando Servidor Web"
echo "=========================================="
echo ""

# Verificar qual servidor web está instalado
if command -v nginx &> /dev/null; then
    echo "✅ Nginx encontrado"
    SERVER="nginx"
elif command -v apache2 &> /dev/null; then
    echo "✅ Apache encontrado"
    SERVER="apache2"
elif command -v httpd &> /dev/null; then
    echo "✅ Apache (httpd) encontrado"
    SERVER="httpd"
else
    echo "❌ Nenhum servidor web encontrado!"
    echo "   Instale Nginx ou Apache primeiro"
    exit 1
fi

# Verificar se está rodando
if systemctl is-active --quiet $SERVER; then
    echo "✅ $SERVER está rodando"
else
    echo "⚠️  $SERVER não está rodando. Iniciando..."
    systemctl start $SERVER
fi

# Ajustar permissões
echo ""
echo "🔐 Ajustando permissões..."
chown -R www-data:www-data "$REMOTE_PATH"
chmod -R 755 "$REMOTE_PATH"

# Verificar se os arquivos estão lá
echo ""
echo "📁 Verificando arquivos..."
if [ -f "$REMOTE_PATH/index.html" ]; then
    echo "✅ index.html encontrado"
    ls -lh "$REMOTE_PATH" | head -10
else
    echo "❌ index.html não encontrado!"
    echo "   Verifique se o upload foi concluído"
fi

# Configurar Nginx
if [ "$SERVER" = "nginx" ]; then
    echo ""
    echo "📝 Configurando Nginx..."
    
    CONFIG_FILE="/etc/nginx/sites-available/task2026"
    
    cat > "$CONFIG_FILE" << 'EOF'
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
    ln -sf "$CONFIG_FILE" /etc/nginx/sites-enabled/task2026
    
    # Testar configuração
    echo ""
    echo "🧪 Testando configuração do Nginx..."
    if nginx -t; then
        echo "✅ Configuração válida!"
        systemctl reload nginx
        echo "✅ Nginx recarregado!"
    else
        echo "❌ Erro na configuração do Nginx!"
        exit 1
    fi
fi

# Configurar Apache
if [ "$SERVER" = "apache2" ] || [ "$SERVER" = "httpd" ]; then
    echo ""
    echo "📝 Configurando Apache..."
    
    # Habilitar mod_rewrite
    a2enmod rewrite 2>/dev/null || echo "⚠️  mod_rewrite pode já estar habilitado"
    
    CONFIG_FILE="/etc/apache2/sites-available/task2026.conf"
    
    cat > "$CONFIG_FILE" << 'EOF'
<VirtualHost *:80>
    ServerName 212.85.0.249
    DocumentRoot /var/www/html/task2026
    
    <Directory /var/www/html/task2026>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Fallback para SPA
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    
    # Gzip compression
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json application/wasm
    </IfModule>
    
    # Cache para assets
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpg "access plus 1 year"
        ExpiresByType image/jpeg "access plus 1 year"
        ExpiresByType image/png "access plus 1 year"
        ExpiresByType text/css "access plus 1 year"
        ExpiresByType application/javascript "access plus 1 year"
        ExpiresByType application/wasm "access plus 1 year"
    </IfModule>
</VirtualHost>
EOF

    # Ativar site
    a2ensite task2026.conf 2>/dev/null || echo "⚠️  Site pode já estar ativado"
    
    # Recarregar Apache
    systemctl reload apache2 2>/dev/null || systemctl reload httpd 2>/dev/null
    echo "✅ Apache configurado e recarregado!"
fi

echo ""
echo "=========================================="
echo "✅ Configuração concluída!"
echo "=========================================="
echo ""
echo "🌐 Acesse a aplicação em:"
echo "   http://212.85.0.249/task2026/"
echo ""
echo "📋 Verificar status:"
echo "   systemctl status $SERVER"
echo ""
