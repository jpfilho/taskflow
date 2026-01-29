#!/bin/bash
# Script para configurar N8N com HTTPS
# Execute no servidor: bash configurar_n8n_https.sh

set -e

DOMAIN="api.taskflowv3.com.br"
N8N_PATH="/n8n"
N8N_PORT="5678"
NGINX_FILE="/etc/nginx/sites-available/supabase"

echo "========================================="
echo "Configuração do N8N com HTTPS"
echo "========================================="
echo ""
echo "Domínio: $DOMAIN"
echo "Path: $N8N_PATH"
echo ""

# 1. Verificar certificado SSL
echo "[1/4] Verificando certificado SSL..."
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "❌ Certificado SSL não encontrado!"
    echo ""
    echo "Execute primeiro: bash configurar_https_taskflow.sh"
    exit 1
fi
echo "✅ Certificado SSL encontrado"
echo ""

# 2. Backup do Nginx
echo "[2/4] Fazendo backup do Nginx..."
if [ -f "$NGINX_FILE" ]; then
    cp "$NGINX_FILE" "${NGINX_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ Backup criado"
else
    echo "❌ Arquivo do Nginx não encontrado: $NGINX_FILE"
    exit 1
fi
echo ""

# 3. Adicionar configuração do N8N
echo "[3/4] Adicionando configuração do N8N..."

# Verificar se já existe
if grep -q "location $N8N_PATH" "$NGINX_FILE" 2>/dev/null; then
    echo "⚠️  Configuração do N8N já existe, removendo antiga..."
    # Remover configuração antiga (do location até o fechamento })
    sed -i "/location $N8N_PATH {/,/^    }/d" "$NGINX_FILE"
fi

# Criar configuração do N8N
N8N_CONFIG="    # N8N via HTTPS
    location $N8N_PATH {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port 443;
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
        proxy_buffering off;
        client_max_body_size 50M;
    }"

# Encontrar o bloco HTTPS (server com listen 443)
# Inserir antes do primeiro "location /" no bloco HTTPS
if grep -q "listen 443" "$NGINX_FILE"; then
    # Usar Python para inserção precisa
    python3 << PYTHON
import re

file_path = "$NGINX_FILE"
n8n_config = """$N8N_CONFIG"""

# Ler arquivo
with open(file_path, 'r') as f:
    lines = f.readlines()

# Encontrar bloco HTTPS e inserir antes do primeiro location /
in_https_block = False
inserted = False
https_start = -1
first_location_slash = -1

for i, line in enumerate(lines):
    if 'listen 443' in line:
        in_https_block = True
        https_start = i
    if in_https_block and not inserted:
        if line.strip() == 'location / {':
            first_location_slash = i
            # Calcular indentação
            indent = len(line) - len(line.lstrip())
            # Adicionar configuração do n8n com indentação correta
            n8n_lines = n8n_config.split('\n')
            indented_n8n = '\n'.join([' ' * indent + n8n_line if n8n_line.strip() else n8n_line for n8n_line in n8n_lines])
            lines.insert(i, indented_n8n + '\n')
            inserted = True
            break

if inserted:
    with open(file_path, 'w') as f:
        f.writelines(lines)
    print("✅ Configuração do N8N adicionada")
else:
    print("⚠️  Não foi possível inserir automaticamente.")
    print("   Adicione manualmente antes do 'location /' no bloco HTTPS:")
    print("")
    print(n8n_config)
    exit(1)
PYTHON
else
    echo "❌ Arquivo do Nginx não contém configuração HTTPS (listen 443)"
    exit 1
fi

# Testar configuração
echo ""
echo "🧪 Testando configuração do Nginx..."
if nginx -t; then
    echo "✅ Configuração válida"
    systemctl reload nginx
    echo "✅ Nginx recarregado"
else
    echo "❌ Erro na configuração do Nginx"
    echo ""
    echo "Revertendo backup..."
    cp "${NGINX_FILE}.backup."* "$NGINX_FILE" 2>/dev/null || true
    exit 1
fi
echo ""

# 4. Atualizar container do N8N
echo "[4/4] Atualizando container do N8N..."

WEBHOOK_URL="https://${DOMAIN}${N8N_PATH}/"

# Parar e remover container atual
docker stop n8n 2>/dev/null || true
docker rm n8n 2>/dev/null || true

# Recriar container com HTTPS
docker run -d \
    --name n8n \
    --restart unless-stopped \
    -p 127.0.0.1:${N8N_PORT}:5678 \
    -v /opt/n8n:/home/node/.n8n \
    -e N8N_BASIC_AUTH_ACTIVE=true \
    -e N8N_BASIC_AUTH_USER=admin \
    -e N8N_BASIC_AUTH_PASSWORD=n8n_admin_2026 \
    -e N8N_HOST=$DOMAIN \
    -e N8N_PORT=443 \
    -e N8N_PROTOCOL=https \
    -e WEBHOOK_URL=$WEBHOOK_URL \
    -e N8N_PATH=$N8N_PATH \
    n8nio/n8n:latest

# Aguardar inicialização
sleep 3

# Verificar status
if docker ps | grep -q n8n; then
    echo "✅ Container N8N criado e rodando"
else
    echo "❌ Erro ao criar container N8N"
    docker logs n8n --tail 20
    exit 1
fi

echo ""
echo "========================================="
echo "Configuração Concluída!"
echo "========================================="
echo ""
echo "N8N agora está acessível via HTTPS:"
echo "  URL: https://${DOMAIN}${N8N_PATH}/"
echo "  Usuário: admin"
echo "  Senha: n8n_admin_2026"
echo ""
echo "Webhook URL para Telegram:"
echo "  $WEBHOOK_URL"
echo ""
echo "⚠️  IMPORTANTE:"
echo "  1. Acesse o N8N e reative o workflow do Telegram"
echo "  2. O webhook será registrado automaticamente com HTTPS"
echo ""
