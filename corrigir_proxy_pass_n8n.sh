#!/bin/bash
# Script para corrigir proxy_pass do N8N removendo o prefixo /n8n

echo "========================================="
echo "Corrigindo proxy_pass do N8N"
echo "========================================="
echo ""

NGINX_FILE="/etc/nginx/sites-available/supabase"

# Backup
cp "$NGINX_FILE" "${NGINX_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup criado"
echo ""

# Verificar configuração atual
echo "Configuração atual do location /n8n:"
grep -A 3 "location /n8n" "$NGINX_FILE" | grep "proxy_pass"
echo ""

# Corrigir: adicionar barra no final do proxy_pass para remover prefixo
if grep -q "location /n8n" "$NGINX_FILE"; then
    # Substituir proxy_pass sem barra por proxy_pass com barra
    sed -i 's|proxy_pass http://127.0.0.1:5678;|proxy_pass http://127.0.0.1:5678/;|g' "$NGINX_FILE"
    
    # Também adicionar rewrite para garantir
    if ! grep -A 5 "location /n8n" "$NGINX_FILE" | grep -q "rewrite"; then
        # Adicionar rewrite após proxy_pass
        sed -i '/location \/n8n {/,/proxy_pass http:\/\/127.0.0.1:5678\/;/ {
            /proxy_pass http:\/\/127.0.0.1:5678\/;/a\
        rewrite ^/n8n/(.*)$ /$1 break;
        rewrite ^/n8n$ / break;
        }' "$NGINX_FILE"
    fi
    
    echo "✅ proxy_pass corrigido (barra adicionada para remover prefixo)"
else
    echo "❌ location /n8n não encontrado!"
    exit 1
fi

echo ""
echo "Nova configuração:"
grep -A 5 "location /n8n" "$NGINX_FILE" | head -6
echo ""

# Testar
echo "🧪 Testando configuração..."
if nginx -t; then
    echo "✅ Configuração válida"
    systemctl reload nginx
    echo "✅ Nginx recarregado"
else
    echo "❌ Erro na configuração"
    echo "Revertendo backup..."
    cp "${NGINX_FILE}.backup."* "$NGINX_FILE" 2>/dev/null || true
    exit 1
fi

echo ""
echo "========================================="
echo "Correção aplicada!"
echo "========================================="
echo ""
echo "Teste agora:"
echo "  curl -k https://api.taskflowv3.com.br/n8n/"
echo ""
