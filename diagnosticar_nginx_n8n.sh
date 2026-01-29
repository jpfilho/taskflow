#!/bin/bash
# Script para diagnosticar problema do N8N no Nginx

echo "========================================="
echo "Diagnóstico Nginx + N8N"
echo "========================================="
echo ""

NGINX_FILE="/etc/nginx/sites-available/supabase"

echo "1. Verificando configuração do location /n8n:"
echo "----------------------------------------"
grep -A 20 "location /n8n" "$NGINX_FILE"
echo "----------------------------------------"
echo ""

echo "2. Verificando proxy_pass:"
PROXY_PASS=$(grep -A 3 "location /n8n" "$NGINX_FILE" | grep "proxy_pass")
echo "   $PROXY_PASS"

if echo "$PROXY_PASS" | grep -q "proxy_pass http://127.0.0.1:5678/;"; then
    echo "   ✅ proxy_pass tem barra no final (correto)"
elif echo "$PROXY_PASS" | grep -q "proxy_pass http://127.0.0.1:5678;"; then
    echo "   ❌ proxy_pass SEM barra no final (precisa corrigir!)"
else
    echo "   ⚠️  proxy_pass não encontrado ou formato diferente"
fi
echo ""

echo "3. Verificando ordem dos locations:"
echo "----------------------------------------"
grep -A 100 "listen 443" "$NGINX_FILE" | grep -n "location" | head -5
echo "----------------------------------------"
echo ""

echo "4. Testando acesso direto ao N8N (porta 5678):"
curl -s http://127.0.0.1:5678/ | head -20
echo ""
echo ""

echo "5. Testando via Nginx (HTTPS):"
curl -k -s https://api.taskflowv3.com.br/n8n/ | head -20
echo ""
echo ""

echo "6. Verificando logs do Nginx (últimas 10 linhas):"
tail -10 /var/log/nginx/error.log 2>/dev/null || echo "   (sem erros recentes)"
echo ""

echo "7. Verificando se N8N está rodando:"
docker ps | grep n8n || echo "   ❌ N8N não está rodando!"
echo ""

echo "========================================="
echo "Diagnóstico completo!"
echo "========================================="
