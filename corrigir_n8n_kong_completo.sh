#!/bin/bash
# Script completo para corrigir erro do Kong no N8N

set -e

NGINX_FILE="/etc/nginx/sites-available/supabase"

echo "========================================="
echo "Correção Completa: N8N + Kong Error"
echo "========================================="
echo ""

# 1. Backup
echo "[1/5] Fazendo backup..."
cp "$NGINX_FILE" "${NGINX_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup criado"
echo ""

# 2. Verificar se location /n8n existe
echo "[2/5] Verificando configuração atual..."
if ! grep -q "location /n8n" "$NGINX_FILE"; then
    echo "❌ location /n8n não encontrado!"
    echo "   Execute primeiro: bash configurar_n8n_https.sh"
    exit 1
fi
echo "✅ location /n8n encontrado"
echo ""

# 3. Remover configuração antiga do /n8n
echo "[3/5] Removendo configuração antiga do /n8n..."
# Remover do location até o fechamento }
sed -i '/location \/n8n {/,/^    }/d' "$NGINX_FILE"
echo "✅ Configuração antiga removida"
echo ""

# 4. Adicionar configuração correta
echo "[4/5] Adicionando configuração correta..."

# Encontrar onde inserir (antes do location / no bloco HTTPS)
if grep -q "listen 443" "$NGINX_FILE"; then
    # Usar Python para inserção precisa
    python3 << PYTHON
import re

file_path = "$NGINX_FILE"

# Configuração correta do N8N com rewrite
n8n_config = """    # N8N via HTTPS
    location /n8n {
        # Remover prefixo /n8n antes de enviar para N8N
        rewrite ^/n8n/(.*)$ /\$1 break;
        rewrite ^/n8n$ / break;
        
        proxy_pass http://127.0.0.1:5678;
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
    }"""

# Ler arquivo
with open(file_path, 'r') as f:
    lines = f.readlines()

# Encontrar bloco HTTPS e inserir antes do primeiro location /
in_https_block = False
inserted = False

for i, line in enumerate(lines):
    if 'listen 443' in line:
        in_https_block = True
    if in_https_block and not inserted:
        if line.strip() == 'location / {':
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
    print("✅ Configuração do N8N adicionada com rewrite")
else:
    print("❌ Não foi possível inserir automaticamente")
    print("   Adicione manualmente antes do 'location /' no bloco HTTPS")
    exit(1)
PYTHON
else
    echo "❌ Arquivo do Nginx não contém configuração HTTPS (listen 443)"
    exit 1
fi

# 5. Testar e recarregar
echo ""
echo "[5/5] Testando e recarregando Nginx..."
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
echo "========================================="
echo "Correção Aplicada!"
echo "========================================="
echo ""
echo "Configuração do location /n8n:"
grep -A 20 "location /n8n" "$NGINX_FILE" | head -21
echo ""
echo "Teste agora:"
echo "  curl -k https://api.taskflowv3.com.br/n8n/"
echo ""
echo "Deve retornar: {\"message\": \"Unauthorized\"}"
echo ""
