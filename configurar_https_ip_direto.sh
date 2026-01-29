#!/bin/bash

# =========================================
# CONFIGURAR HTTPS PARA SUPABASE - IP DIRETO
# =========================================
# Servidor: 212.85.0.249
# Solução alternativa sem DNS (usando certificado auto-assinado ou Let's Debug)
# 
# Execute no servidor via SSH:
# bash configurar_https_ip_direto.sh

set -e

SERVER_IP="212.85.0.249"
SUPABASE_PORT=8000

echo "🚀 Configurando HTTPS para Supabase (IP Direto)"
echo "==============================================="
echo "IP: $SERVER_IP"
echo "Porta Supabase: $SUPABASE_PORT"
echo ""
echo "⚠️  NOTA: Como vamos usar IP direto, usaremos certificado auto-assinado"
echo "         Para Telegram webhook, isso não é problema se configurarmos corretamente."
echo ""

# =========================================
# 1. ATUALIZAR SISTEMA
# =========================================

echo "📦 Atualizando sistema..."
apt update
apt upgrade -y

# =========================================
# 2. INSTALAR NGINX E OPENSSL
# =========================================

echo "📦 Instalando Nginx e OpenSSL..."
apt install nginx openssl -y

# =========================================
# 3. CRIAR CERTIFICADO AUTO-ASSINADO
# =========================================

echo "🔐 Criando certificado SSL auto-assinado..."

mkdir -p /etc/nginx/ssl

# Gerar certificado auto-assinado (válido por 1 ano)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/supabase.key \
    -out /etc/nginx/ssl/supabase.crt \
    -subj "/C=BR/ST=State/L=City/O=Organization/OU=IT/CN=$SERVER_IP"

echo ""
echo "✅ Certificado SSL criado!"
echo ""

# =========================================
# 4. CONFIGURAR NGINX
# =========================================

echo "⚙️  Configurando Nginx..."

# Backup da configuração padrão
if [ -f /etc/nginx/sites-enabled/default ]; then
    mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup
fi

# Criar configuração para Supabase
cat > /etc/nginx/sites-available/supabase << 'EOF'
# HTTP (porta 80) - Redirecionar para HTTPS
server {
    listen 80;
    server_name 212.85.0.249 api.taskflow3.com.br;
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS (porta 443)
server {
    listen 443 ssl http2;
    server_name 212.85.0.249 api.taskflow3.com.br;

    # Certificado SSL auto-assinado
    ssl_certificate /etc/nginx/ssl/supabase.crt;
    ssl_certificate_key /etc/nginx/ssl/supabase.key;
    
    # Configurações SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

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
# 5. INICIAR NGINX
# =========================================

echo ""
echo "🚀 Iniciando Nginx..."
systemctl restart nginx
systemctl enable nginx

# =========================================
# 6. CONFIGURAR FIREWALL (UFW)
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
# 7. TESTAR HTTPS
# =========================================

echo ""
echo "🧪 Testando HTTPS..."
sleep 3

# Testar (ignorando certificado auto-assinado)
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://$SERVER_IP)

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ HTTPS funcionando! (HTTP $HTTP_CODE)"
else
    echo "⚠️  HTTPS responde com código: $HTTP_CODE"
fi

# =========================================
# 8. EXPORTAR CERTIFICADO (PARA TELEGRAM)
# =========================================

echo ""
echo "📦 Exportando certificado público..."

cp /etc/nginx/ssl/supabase.crt /root/supabase_cert.pem

echo ""
echo "✅ Certificado salvo em: /root/supabase_cert.pem"
echo ""

# =========================================
# 9. RESUMO
# =========================================

echo ""
echo "========================================"
echo "✅ CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!"
echo "========================================"
echo ""
echo "📋 Informações:"
echo "   URL: https://$SERVER_IP"
echo "   Certificado: /etc/nginx/ssl/supabase.crt"
echo "   Chave privada: /etc/nginx/ssl/supabase.key"
echo "   Config Nginx: /etc/nginx/sites-available/supabase"
echo "   Logs Nginx: /var/log/nginx/supabase_*.log"
echo ""
echo "⚠️  IMPORTANTE - Certificado Auto-Assinado:"
echo "   O certificado é auto-assinado, então navegadores vão mostrar aviso."
echo "   Mas para Telegram webhook, podemos enviar o certificado junto!"
echo ""
echo "🧪 Testar:"
echo "   curl -k https://$SERVER_IP"
echo ""
echo "📝 Próximos passos:"
echo ""
echo "1️⃣  Atualizar Flutter (supabase_config.dart):"
echo "   static const String supabaseUrl = 'https://$SERVER_IP';"
echo ""
echo "2️⃣  Configurar webhook Telegram COM certificado:"
echo "   curl -F \"url=https://$SERVER_IP/functions/v1/telegram-webhook\" \\"
echo "        -F \"certificate=@/root/supabase_cert.pem\" \\"
echo "        https://api.telegram.org/bot<TOKEN>/setWebhook"
echo ""
echo "3️⃣  Fazer deploy das Edge Functions:"
echo "   cd /opt/supabase && docker-compose restart edge-functions"
echo ""
