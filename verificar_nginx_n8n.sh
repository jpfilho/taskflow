#!/bin/bash
# Script para verificar configuração do Nginx para N8N

echo "========================================="
echo "Verificando configuração do Nginx"
echo "========================================="
echo ""

NGINX_FILE="/etc/nginx/sites-available/supabase"

echo "1. Verificando se location /n8n existe:"
if grep -q "location /n8n" "$NGINX_FILE"; then
    echo "   ✅ location /n8n encontrado"
else
    echo "   ❌ location /n8n NÃO encontrado!"
    exit 1
fi

echo ""
echo "2. Verificando ordem dos locations (location /n8n deve estar ANTES de location /):"

# Encontrar linha do location /n8n
LINE_N8N=$(grep -n "location /n8n" "$NGINX_FILE" | head -1 | cut -d: -f1)
# Encontrar linha do location / (primeiro após listen 443)
LINE_ROOT=$(grep -A 50 "listen 443" "$NGINX_FILE" | grep -n "location / {" | head -1 | cut -d: -f1)

if [ -n "$LINE_N8N" ] && [ -n "$LINE_ROOT" ]; then
    # Ajustar LINE_ROOT para linha absoluta (adicionar offset do bloco HTTPS)
    HTTPS_START=$(grep -n "listen 443" "$NGINX_FILE" | head -1 | cut -d: -f1)
    LINE_ROOT_ABS=$((HTTPS_START + LINE_ROOT - 1))
    
    echo "   Linha do location /n8n: $LINE_N8N"
    echo "   Linha do location /: $LINE_ROOT_ABS"
    
    if [ "$LINE_N8N" -lt "$LINE_ROOT_ABS" ]; then
        echo "   ✅ Ordem correta: location /n8n está ANTES de location /"
    else
        echo "   ❌ Ordem INCORRETA: location /n8n está DEPOIS de location /"
        echo "   ⚠️  Isso faz o Nginx processar location / primeiro!"
    fi
else
    echo "   ⚠️  Não foi possível determinar a ordem"
fi

echo ""
echo "3. Mostrando configuração do location /n8n:"
echo "----------------------------------------"
grep -A 20 "location /n8n" "$NGINX_FILE" | head -21
echo "----------------------------------------"

echo ""
echo "4. Verificando se proxy_pass está correto:"
if grep -A 5 "location /n8n" "$NGINX_FILE" | grep -q "proxy_pass http://127.0.0.1:5678"; then
    echo "   ✅ proxy_pass correto (porta 5678)"
else
    echo "   ❌ proxy_pass incorreto ou não encontrado"
fi

echo ""
echo "5. Verificando headers HTTPS:"
if grep -A 15 "location /n8n" "$NGINX_FILE" | grep -q "X-Forwarded-Proto https"; then
    echo "   ✅ X-Forwarded-Proto https encontrado"
else
    echo "   ⚠️  X-Forwarded-Proto https não encontrado"
fi

echo ""
echo "6. Testando sintaxe do Nginx:"
nginx -t

echo ""
echo "========================================="
echo "Diagnóstico completo!"
echo "========================================="
