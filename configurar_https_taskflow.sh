#!/bin/bash

# =========================================
# CONFIGURAR HTTPS PARA SUPABASE
# =========================================
# Domínio: api.taskflow3.com.br
# Servidor: 212.85.0.249
# 
# Execute no servidor via SSH:
# bash configurar_https_taskflow.sh

set -e

DOMAIN="api.taskflow3.com.br"
EMAIL="filhocefet1@gmail.com"  # ⚠️ ALTERE PARA SEU EMAIL
SUPABASE_PORT=8000

echo "🚀 Configurando HTTPS para Supabase"
echo "===================================="
echo "Domínio: $DOMAIN"
echo "Porta Supabase: $SUPABASE_PORT"
echo ""

# =========================================
# 1. ATUALIZAR SISTEMA
# =========================================

echo "📦 Atualizando sistema..."
apt update
apt upgrade -y

# =========================================
# 2. INSTALAR NGINX E CERTBOT
# =========================================

echo "📦 Instalando Nginx e Certbot..."
apt install nginx certbot python3-certbot-nginx -y

# =========================================
# 3. PARAR NGINX TEMPORARIAMENTE
# =========================================

echo "🛑 Parando Nginx temporariamente..."
systemctl stop nginx

# =========================================
# 4. GERAR CERTIFICADO SSL
# =========================================

echo "🔐 Gerando certificado SSL..."
certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN"

if [ $? -ne 0 ]; then
    echo "❌ Erro ao gerar certificado SSL"
    echo ""
    echo "Possíveis causas:"
    echo "1. DNS ainda não propagou (aguarde 5-10 minutos)"
    echo "2. Email inválido"
    echo "3. Porta 80 não está liberada"
    echo ""
    echo "Verifique e tente novamente."
    exit 1
fi

echo ""
echo "✅ Certificado SSL gerado!"
echo ""

# =========================================
# 5. CONFIGURAR NGINX
# =========================================

echo "⚙️  Configurando Nginx..."

# Backup da configuração padrão
if [ -f /etc/nginx/sites-enabled/default ]; then
    mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup
fi

# Criar configuração para Supabase
cat > /etc/nginx/sites-available/supabase << 'EOF'
# Redirecionar HTTP para HTTPS
server {
    listen 80;
    server_name api.taskflow3.com.br;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    server_name api.taskflow3.com.br;

    # Certificado SSL
    ssl_certificate /etc/letsencrypt/live/api.taskflow3.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.taskflow3.com.br/privkey.pem;
    
    # Configurações SSL otimizadas
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Aumentar timeout para uploads
    client_max_body_size 50M;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300;

    # Logs
    access_log /var/log/nginx/supabase_access.log;
    error_log /var/log/nginx/supabase_error.log;

    # Proxy para Supabase
    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Ativar configuração
ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/supabase

# Testar configuração
echo ""
echo "🧪 Testando configuração do Nginx..."
nginx -t

if [ $? -ne 0 ]; then
    echo "❌ Erro na configuração do Nginx"
    exit 1
fi

# =========================================
# 6. INICIAR NGINX
# =========================================

echo ""
echo "🚀 Iniciando Nginx..."
systemctl start nginx
systemctl enable nginx

# =========================================
# 7. CONFIGURAR RENOVAÇÃO AUTOMÁTICA SSL
# =========================================

echo ""
echo "🔄 Configurando renovação automática do SSL..."

# Testar renovação
certbot renew --dry-run

# Criar hook para recarregar nginx após renovação
mkdir -p /etc/letsencrypt/renewal-hooks/post
cat > /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh << 'EOF'
#!/bin/bash
systemctl reload nginx
EOF
chmod +x /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh

# =========================================
# 8. CONFIGURAR FIREWALL (UFW)
# =========================================

echo ""
echo "🔒 Configurando firewall..."

if command -v ufw &> /dev/null; then
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    echo "✅ Firewall configurado"
else
    echo "⚠️  UFW não instalado, pulando configuração de firewall"
fi

# =========================================
# 9. TESTAR HTTPS
# =========================================

echo ""
echo "🧪 Testando HTTPS..."
sleep 3

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN)

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ HTTPS funcionando! (HTTP $HTTP_CODE)"
else
    echo "⚠️  HTTPS responde com código: $HTTP_CODE"
fi

# =========================================
# 10. RESUMO
# =========================================

echo ""
echo "========================================"
echo "✅ CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!"
echo "========================================"
echo ""
echo "📋 Informações:"
echo "   Domínio: https://$DOMAIN"
echo "   Certificado: /etc/letsencrypt/live/$DOMAIN/"
echo "   Config Nginx: /etc/nginx/sites-available/supabase"
echo "   Logs Nginx: /var/log/nginx/supabase_*.log"
echo ""
echo "🧪 Testar:"
echo "   curl https://$DOMAIN"
echo ""
echo "📝 Próximos passos:"
echo ""
echo "1️⃣  Atualizar Flutter (supabase_config.dart):"
echo "   static const String supabaseUrl = 'https://$DOMAIN';"
echo ""
echo "2️⃣  Configurar webhook Telegram:"
echo "   .\configurar_webhook.ps1"
echo ""
echo "3️⃣  Fazer deploy das Edge Functions:"
echo "   .\deploy_telegram_functions.ps1"
echo ""
echo "🔄 Renovação SSL:"
echo "   Automática (certbot renew roda 2x por dia)"
echo "   Testar: certbot renew --dry-run"
echo ""
