#!/bin/bash
# Diagnóstico completo do roteamento Nginx

NGINX_FILE="/etc/nginx/sites-available/supabase"

echo "========================================="
echo "Diagnóstico: Roteamento Nginx"
echo "========================================="
echo ""

echo "1. Verificando TODOS os locations no arquivo:"
echo "----------------------------------------"
grep -n "location" "$NGINX_FILE"
echo "----------------------------------------"
echo ""

echo "2. Verificando ordem no bloco HTTPS:"
echo "----------------------------------------"
grep -A 150 "listen 443" "$NGINX_FILE" | grep -n "location" | head -10
echo "----------------------------------------"
echo ""

echo "3. Configuração completa do location /n8n:"
echo "----------------------------------------"
grep -A 25 "location /n8n" "$NGINX_FILE"
echo "----------------------------------------"
echo ""

echo "4. Configuração do location / (Supabase):"
echo "----------------------------------------"
grep -A 10 "location / {" "$NGINX_FILE" | head -15
echo "----------------------------------------"
echo ""

echo "5. Testando requisição simulada:"
echo "----------------------------------------"
echo "Testando: curl -k https://api.taskflowv3.com.br/n8n/"
RESPONSE=$(curl -k -s https://api.taskflowv3.com.br/n8n/ 2>&1)
echo "Resposta: $RESPONSE"
echo ""

if echo "$RESPONSE" | grep -q "Kong Error\|kong\|Invalid authentication"; then
    echo "❌ PROBLEMA: Resposta veio do Kong/Supabase!"
    echo "   O Nginx está enviando para Supabase ao invés do N8N."
elif echo "$RESPONSE" | grep -q "Unauthorized\|n8n"; then
    echo "✅ Resposta veio do N8N (correto)"
else
    echo "⚠️  Resposta não reconhecida"
fi
echo ""

echo "6. Verificando logs do Nginx (últimas 5 linhas de acesso):"
echo "----------------------------------------"
tail -5 /var/log/nginx/access.log 2>/dev/null | grep "/n8n" || echo "   (sem acessos recentes a /n8n)"
echo "----------------------------------------"
echo ""

echo "7. Verificando se há outros locations interferindo:"
echo "----------------------------------------"
grep -n "location" "$NGINX_FILE" | grep -v "location /n8n" | grep -v "location / {"
echo "----------------------------------------"
echo ""
