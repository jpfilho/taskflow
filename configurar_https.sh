#!/bin/bash

# Script para executar NO SERVIDOR
# Configura HTTPS com Let's Encrypt

echo "=========================================="
echo "Configurando HTTPS com Let's Encrypt"
echo "=========================================="
echo ""

# Verificar se já tem domínio configurado
echo "📋 IMPORTANTE: Para usar Let's Encrypt, você precisa de um domínio apontando para o IP 212.85.0.249"
echo "   Se não tiver domínio, você pode usar um serviço como DuckDNS ou No-IP"
echo ""

read -p "Você tem um domínio configurado? (s/n): " tem_dominio

if [ "$tem_dominio" != "s" ] && [ "$tem_dominio" != "S" ]; then
    echo ""
    echo "⚠️  Sem domínio, não é possível usar Let's Encrypt."
    echo ""
    echo "💡 OPÇÕES:"
    echo "   1. Usar DuckDNS (gratuito): https://www.duckdns.org/"
    echo "   2. Usar No-IP (gratuito): https://www.noip.com/"
    echo "   3. Configurar certificado auto-assinado (não recomendado para produção)"
    echo ""
    exit 1
fi

read -p "Digite o domínio (ex: meusite.com ou app.meusite.com): " dominio

if [ -z "$dominio" ]; then
    echo "❌ Domínio não pode ser vazio!"
    exit 1
fi

echo ""
echo "🔍 Verificando se o domínio aponta para este servidor..."
dig +short $dominio

echo ""
read -p "O IP acima corresponde a 212.85.0.249? (s/n): " ip_correto

if [ "$ip_correto" != "s" ] && [ "$ip_correto" != "S" ]; then
    echo "⚠️  Configure o DNS do domínio para apontar para 212.85.0.249 primeiro!"
    exit 1
fi

# Instalar Certbot
echo ""
echo "📦 Instalando Certbot..."
apt update
apt install -y certbot python3-certbot-nginx

# Configurar Nginx para HTTPS
echo ""
echo "📝 Configurando Nginx para HTTPS..."
cat > /etc/nginx/sites-available/task2026 << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $dominio 212.85.0.249;
    
    # Redirecionar HTTP para HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $dominio 212.85.0.249;
    
    root /var/www/html/task2026;
    index index.html;
    
    # SSL será configurado pelo Certbot
    # Certbot adicionará automaticamente:
    # ssl_certificate /etc/letsencrypt/live/$dominio/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$dominio/privkey.pem;
    
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
        try_files \$uri \$uri/ /index.html;
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
certbot --nginx -d $dominio --non-interactive --agree-tos --email admin@$dominio --redirect

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ HTTPS configurado com sucesso!"
    echo "=========================================="
    echo ""
    echo "🌐 Acesse a aplicação em:"
    echo "   https://$dominio/task2026/"
    echo "   ou"
    echo "   https://212.85.0.249/task2026/"
    echo ""
    echo "📋 O certificado será renovado automaticamente."
    echo ""
else
    echo ""
    echo "❌ Erro ao obter certificado SSL!"
    echo "   Verifique se:"
    echo "   1. O domínio está apontando para 212.85.0.249"
    echo "   2. A porta 80 está acessível externamente"
    echo "   3. Não há firewall bloqueando as portas 80 e 443"
    echo ""
fi
