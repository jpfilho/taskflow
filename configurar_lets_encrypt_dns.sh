#!/bin/bash
# Configurar Let's Encrypt para api.taskflow3.com.br

set -e

DOMAIN="api.taskflow3.com.br"
EMAIL="jpfilho@axia.com.br"

echo "========================================="
echo " CONFIGURAR LET'S ENCRYPT"
echo "========================================="
echo ""

# Atualizar sistema
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Parar Nginx temporariamente
systemctl stop nginx

# Obter certificado (standalone mode)
certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  --domains "$DOMAIN" \
  --preferred-challenges http

# Configurar Nginx para usar o certificado
cat > /etc/nginx/sites-available/api_taskflow <<'EOF'
server {
    listen 80;
    server_name api.taskflow3.com.br;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.taskflow3.com.br;

    ssl_certificate /etc/letsencrypt/live/api.taskflow3.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflow3.com.br/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Proxy para Supabase
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Ativar site
ln -sf /etc/nginx/sites-available/api_taskflow /etc/nginx/sites-enabled/

# Remover configuração antiga do IP se existir
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/supabase_ssl

# Testar configuração
nginx -t

# Iniciar Nginx
systemctl start nginx
systemctl enable nginx

# Configurar renovação automática
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

echo ""
echo "========================================="
echo " CONFIGURACAO CONCLUIDA!"
echo "========================================="
echo ""
echo "Dominio: https://api.taskflow3.com.br"
echo "Certificado: Let's Encrypt"
echo "Renovacao automatica: Ativada"
echo ""
