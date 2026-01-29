#!/bin/bash
# Script para corrigir location /n8n no Nginx

set -e

NGINX_FILE="/etc/nginx/sites-available/supabase"

# Remover todas as configurações antigas de /n8n
echo "Removendo configurações antigas..."
sed -i '/location \/n8n/,/^    }/d' "$NGINX_FILE"
echo "✅ Configurações antigas removidas"

# Adicionar location /n8n no início do bloco HTTPS usando Python
python3 << 'PYTHON_SCRIPT'
import re

file_path = "/etc/nginx/sites-available/supabase"

# Configuração correta do N8N com rewrite
n8n_config = """    # N8N via HTTPS - DEVE estar ANTES de location /
    location /n8n {
        rewrite ^/n8n/(.*)$ /$1 break;
        rewrite ^/n8n$ / break;
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
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

# Encontrar linha do "listen 443" e inserir logo depois
inserted = False
for i, line in enumerate(lines):
    if 'listen 443' in line:
        # Calcular indentação
        j = i + 1
        while j < len(lines) and (lines[j].strip() == '' or lines[j].strip().startswith('#')):
            j += 1
        if j < len(lines):
            indent = len(lines[j]) - len(lines[j].lstrip())
        else:
            indent = 4
        
        # Inserir após configurações SSL básicas
        insert_pos = i + 1
        for k in range(i + 1, min(i + 20, len(lines))):
            if 'ssl_certificate' in lines[k] or 'ssl_protocols' in lines[k] or 'client_max_body_size' in lines[k]:
                insert_pos = k + 1
            elif 'location' in lines[k]:
                break
        
        # Adicionar configuração com indentação correta
        n8n_lines = n8n_config.split('\n')
        indented_n8n = '\n'.join([' ' * indent + n8n_line if n8n_line.strip() else n8n_line for n8n_line in n8n_lines])
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
PYTHON_SCRIPT

echo ""
echo "Verificando ordem final:"
grep -A 150 "listen 443" "$NGINX_FILE" | grep -n "location" | head -5
