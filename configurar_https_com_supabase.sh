#!/bin/bash

# Script para executar NO SERVIDOR
# Configura HTTPS com Let's Encrypt para domínio que já tem Supabase

DOMINIO="taskflowv3.com.br"
SUPABASE_PORT=8000  # Porta padrão do Supabase, ajuste se necessário

echo "=========================================="
echo "Configurando HTTPS para $DOMINIO"
echo "Aplicação Flutter + Supabase"
echo "=========================================="
echo ""

# Verificar se o domínio aponta para este servidor
echo "🔍 Verificando DNS..."
IP_DOMINIO=$(dig +short $DOMINIO | head -1)
IP_SERVIDOR="212.85.0.249"

if [ "$IP_DOMINIO" != "$IP_SERVIDOR" ]; then
    echo "⚠️  ATENÇÃO: O domínio $DOMINIO aponta para $IP_DOMINIO"
    echo "   Este servidor tem IP $IP_SERVIDOR"
    echo "   Certifique-se de que o DNS está correto antes de continuar."
    echo ""
    read -p "Continuar mesmo assim? (s/n): " continuar
    if [ "$continuar" != "s" ] && [ "$continuar" != "S" ]; then
        exit 1
    fi
fi

# Verificar porta do Supabase
echo ""
echo "🔍 Verificando porta do Supabase..."
if docker ps | grep -q supabase; then
    SUPABASE_PORT=$(docker ps --format "{{.Ports}}" | grep -oP '0.0.0.0:\K[0-9]+' | head -1)
    if [ -z "$SUPABASE_PORT" ]; then
        SUPABASE_PORT=8000
    fi
    echo "   Supabase encontrado na porta: $SUPABASE_PORT"
else
    echo "   Supabase não encontrado em Docker, usando porta padrão: $SUPABASE_PORT"
    read -p "   Digite a porta do Supabase (ou Enter para $SUPABASE_PORT): " porta_input
    if [ ! -z "$porta_input" ]; then
        SUPABASE_PORT=$porta_input
    fi
fi

# Instalar Certbot
echo ""
echo "📦 Instalando Certbot..."
apt update
apt install -y certbot python3-certbot-nginx

# Configurar Nginx
echo ""
echo "📝 Configurando Nginx..."
cat > /etc/nginx/sites-available/task2026 << EOF
# Redirecionar HTTP para HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMINIO www.$DOMINIO;
    
    # Permitir validação do Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirecionar todo o resto para HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# Configuração HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMINIO www.$DOMINIO;
    
    # SSL será configurado pelo Certbot
    # Certbot adicionará automaticamente:
    # ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;
    
    # Configurações SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Aplicação Flutter - /task2026/
    location /task2026/ {
        alias /var/www/html/task2026/;
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
        try_files \$uri \$uri/ /task2026/index.html;
    }
    
    # Supabase - Proxy reverso
    location / {
        proxy_pass http://localhost:$SUPABASE_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
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

if [ $? -ne 0 ]; then
    echo "❌ Erro na configuração do Nginx!"
    exit 1
fi

# Recarregar Nginx
echo ""
echo "🔄 Recarregando Nginx..."
systemctl reload nginx

# Obter certificado SSL
echo ""
echo "🔐 Obtendo certificado SSL do Let's Encrypt..."
echo "   Isso pode levar alguns minutos..."
echo ""

# Primeiro, obter certificado apenas para validação
certbot certonly --nginx -d $DOMINIO -d www.$DOMINIO --non-interactive --agree-tos --email admin@$DOMINIO --keep-until-expiring

if [ $? -eq 0 ]; then
    # Atualizar configuração com certificados
    echo ""
    echo "📝 Atualizando configuração com certificados SSL..."
    
    # Criar configuração final com certificados
    cat > /etc/nginx/sites-available/task2026 << EOF
# Redirecionar HTTP para HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMINIO www.$DOMINIO;
    
    # Permitir validação do Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirecionar todo o resto para HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# Configuração HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMINIO www.$DOMINIO;
    
    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;
    
    # Configurações SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Aplicação Flutter - /task2026/
    location /task2026/ {
        alias /var/www/html/task2026/;
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
        try_files \$uri \$uri/ /task2026/index.html;
    }
    
    # Supabase - Proxy reverso
    location / {
        proxy_pass http://localhost:$SUPABASE_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
EOF
    
    # Testar e recarregar
    nginx -t
    if [ $? -eq 0 ]; then
        systemctl reload nginx
        
        echo ""
        echo "=========================================="
        echo "✅ HTTPS configurado com sucesso!"
        echo "=========================================="
        echo ""
        echo "🌐 Acesse:"
        echo "   Aplicação Flutter: https://$DOMINIO/task2026/"
        echo "   Supabase: https://$DOMINIO/"
        echo ""
        echo "📋 O certificado será renovado automaticamente."
        echo ""
    else
        echo "❌ Erro ao aplicar configuração SSL!"
    fi
else
    echo ""
    echo "❌ Erro ao obter certificado SSL!"
    echo ""
    echo "💡 Verifique:"
    echo "   1. O domínio $DOMINIO aponta para este servidor"
    echo "   2. A porta 80 está acessível externamente"
    echo "   3. Não há firewall bloqueando"
    echo ""
    echo "   Para tentar novamente:"
    echo "   certbot --nginx -d $DOMINIO -d www.$DOMINIO"
    echo ""
fi
