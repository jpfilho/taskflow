#!/bin/bash

# Script para executar NO SERVIDOR
# Verifica se o Nginx está funcionando na porta 8080

echo "=========================================="
echo "Verificando Nginx na Porta 8080"
echo "=========================================="
echo ""

# 1. Verificar status do Nginx
echo "📊 Status do Nginx:"
systemctl status nginx --no-pager -l

echo ""
echo "=========================================="
echo ""

# 2. Verificar se está escutando na porta 8080
echo "🔍 Verificando porta 8080:"
netstat -tulpn | grep :8080 || ss -tulpn | grep :8080

echo ""
echo "=========================================="
echo ""

# 3. Testar configuração
echo "✅ Testando configuração do Nginx:"
nginx -t

echo ""
echo "=========================================="
echo ""

# 4. Verificar se os arquivos estão no lugar
echo "📁 Verificando arquivos da aplicação:"
ls -lah /var/www/html/task2026/ | head -20

echo ""
echo "=========================================="
echo ""

# 5. Verificar permissões
echo "🔐 Verificando permissões:"
ls -ld /var/www/html/task2026/

echo ""
echo "=========================================="
echo ""

# 6. Testar acesso local
echo "🌐 Testando acesso local:"
curl -I http://localhost:8080/task2026/ 2>&1 | head -10

echo ""
echo "=========================================="
echo ""

echo "✅ Se tudo estiver OK, acesse:"
echo "   http://212.85.0.249:8080/task2026/"
echo ""
