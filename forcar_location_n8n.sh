#!/bin/bash
# Script para FORÇAR o location /n8n a ser processado primeiro

set -e

NGINX_FILE="/etc/nginx/sites-available/supabase"

echo "========================================="
echo "Forçando location /n8n a ser processado primeiro"
echo "========================================="
echo ""

# Backup
cp "$NGINX_FILE" "${NGINX_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup criado"
echo ""

# Verificar se está no bloco HTTPS
if ! grep -q "listen 443" "$NGINX_FILE"; then
    echo "❌ Arquivo não contém bloco HTTPS (listen 443)"
    exit 1
fi

echo "Removendo TODAS as configurações de location /n8n existentes..."
# Remover todas as ocorrências de location /n8n
sed -i '/location \/n8n/,/^    }/d' "$NGINX_FILE"
echo "✅ Configurações antigas removidas"
echo ""

echo "Adicionando location /n8n no INÍCIO do bloco HTTPS (logo após listen 443)..."
python3 << PYTHON
import re

file_path = "$NGINX_FILE"

# Configuração do N8N com rewrite
n8n_config = """    # N8N via HTTPS - DEVE estar ANTES de location /
    location /n8n {
        # Remover prefixo /n8n
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
    }
"""

with open(file_path, 'r') as f:
    lines = f.readlines()

# Encontrar linha do "listen 443" e inserir logo depois (antes de qualquer location)
inserted = False
for i, line in enumerate(lines):
    if 'listen 443' in line:
        # Encontrar próxima linha não vazia e não comentário para calcular indentação
        j = i + 1
        while j < len(lines) and (lines[j].strip() == '' or lines[j].strip().startswith('#')):
            j += 1
        if j < len(lines):
            indent = len(lines[j]) - len(lines[j].lstrip())
        else:
            indent = 4  # padrão
        
        # Inserir location /n8n logo após listen 443, antes de qualquer location
        n8n_lines = n8n_config.split('\n')
        indented_n8n = '\n'.join([' ' * indent + n8n_line if n8n_line.strip() else n8n_line for n8n_line in n8n_lines])
        
        # Inserir após a linha do listen 443 (ou após algumas linhas de configuração SSL)
        # Procurar por um bom lugar para inserir (após configurações SSL básicas)
        insert_pos = i + 1
        # Pular algumas linhas de configuração SSL se existirem
        for k in range(i + 1, min(i + 20, len(lines))):
            if 'ssl_certificate' in lines[k] or 'ssl_protocols' in lines[k] or 'client_max_body_size' in lines[k]:
                insert_pos = k + 1
            elif 'location' in lines[k] or 'server_name' in lines[k] and k > i + 5:
                break
        
        lines.insert(insert_pos, indented_n8n + '\n')
        inserted = True
        break

if inserted:
    with open(file_path, 'w') as f:
        f.writelines(lines)
    print("✅ location /n8n inserido no início do bloco HTTPS")
else:
    print("❌ Não foi possível inserir")
    exit(1)
PYTHON

echo ""
echo "Verificando ordem final dos locations:"
echo "----------------------------------------"
grep -A 150 "listen 443" "$NGINX_FILE" | grep -n "location" | head -5
echo "----------------------------------------"
echo ""

echo "Testando configuração..."
if nginx -t; then
    echo "✅ Configuração válida"
    systemctl reload nginx
    echo "✅ Nginx recarregado"
    echo ""
    echo "Teste agora:"
    echo "  curl -k https://api.taskflowv3.com.br/n8n/"
    echo ""
else
    echo "❌ Erro na configuração"
    echo "Revertendo backup..."
    cp "${NGINX_FILE}.backup."* "$NGINX_FILE" 2>/dev/null || true
    exit 1
fi
