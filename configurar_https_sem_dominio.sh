#!/bin/bash

# Script para executar NO SERVIDOR
# Configura HTTPS com certificado auto-assinado (para testes)
# ⚠️ AVISO: Certificado auto-assinado mostrará aviso no navegador

echo "=========================================="
echo "Configurando HTTPS com Certificado Auto-assinado"
echo "=========================================="
echo "⚠️  AVISO: Certificado auto-assinado mostrará aviso de segurança no navegador"
echo ""

# Instalar OpenSSL se não estiver instalado
apt update
apt install -y openssl

# Criar diretório para certificados
mkdir -p /etc/nginx/ssl

# Gerar certificado auto-assinado
echo ""
echo "🔐 Gerando certificado auto-assinado..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/task2026.key \
    -out /etc/nginx/ssl/task2026.crt \
    -subj "/C=BR/ST=State/L=City/O=Organization/CN=212.85.0.249"

# Configurar Nginx para HTTPS
echo ""
echo "📝 Configurando Nginx para HTTPS..."
cat > /etc/nginx/sites-available/task2026 << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name 212.85.0.249;
    
    # Redirecionar HTTP para HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name 212.85.0.249;
    
    root /var/www/html/task2026;
    index index.html;
    
    # Certificado SSL auto-assinado
    ssl_certificate /etc/nginx/ssl/task2026.crt;
    ssl_certificate_key /etc/nginx/ssl/task2026.key;
    
    # Configurações SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
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
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
EOF

# Ativar site
ln -sf /etc/nginx/sites-available/task2026 /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Testar configuração
echo ""
echo "🧪 Testando configuração do Nginx..."
nginx -t

if [ $? -eq 0 ]; then
    # Recarregar Nginx
    echo ""
    echo "🔄 Recarregando Nginx..."
    systemctl reload nginx
    
    echo ""
    echo "=========================================="
    echo "✅ HTTPS configurado com certificado auto-assinado!"
    echo "=========================================="
    echo ""
    echo "🌐 Acesse a aplicação em:"
    echo "   https://212.85.0.249/task2026/"
    echo ""
    echo "⚠️  O navegador mostrará um aviso de segurança."
    echo "   Clique em 'Avançado' e depois 'Continuar para o site'."
    echo ""
else
    echo ""
    echo "❌ Erro na configuração do Nginx!"
    echo ""
fi
