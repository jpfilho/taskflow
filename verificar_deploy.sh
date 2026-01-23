#!/bin/bash

# ============================================
# Script de Verificação do Deploy
# ============================================

SERVER="root@212.85.0.249"
REMOTE_PATH="/var/www/html/task2026"

echo "=========================================="
echo "Verificando Deploy da Aplicação"
echo "=========================================="
echo ""

# 1. Verificar se os arquivos existem
echo "1️⃣ Verificando arquivos no servidor..."
ssh "$SERVER" "
    echo '📁 Conteúdo do diretório:'
    ls -lah $REMOTE_PATH/ | head -15
    echo ''
    echo '📄 Verificando index.html:'
    if [ -f $REMOTE_PATH/index.html ]; then
        echo '✅ index.html existe'
        head -20 $REMOTE_PATH/index.html | grep -A 2 'base href'
    else
        echo '❌ index.html NÃO existe!'
    fi
    echo ''
    echo '📄 Verificando main.dart.js:'
    if [ -f $REMOTE_PATH/main.dart.js ]; then
        echo '✅ main.dart.js existe'
        ls -lh $REMOTE_PATH/main.dart.js
    else
        echo '❌ main.dart.js NÃO existe!'
    fi
    echo ''
    echo '📄 Verificando version.txt:'
    if [ -f $REMOTE_PATH/version.txt ]; then
        echo '✅ version.txt existe'
        cat $REMOTE_PATH/version.txt
    else
        echo '❌ version.txt NÃO existe!'
    fi
"

echo ""
echo "2️⃣ Verificando configuração do Nginx..."
ssh "$SERVER" "
    if [ -f /etc/nginx/sites-available/task2026 ]; then
        echo '✅ Arquivo de configuração existe'
        echo ''
        echo '📋 Conteúdo da configuração:'
        cat /etc/nginx/sites-available/task2026
    else
        echo '❌ Arquivo de configuração NÃO existe!'
    fi
    echo ''
    echo '🔗 Verificando link simbólico:'
    if [ -L /etc/nginx/sites-enabled/task2026 ]; then
        echo '✅ Link simbólico existe'
        ls -l /etc/nginx/sites-enabled/task2026
    else
        echo '❌ Link simbólico NÃO existe!'
    fi
    echo ''
    echo '🧪 Testando configuração do Nginx:'
    nginx -t 2>&1
    echo ''
    echo '📊 Status do Nginx:'
    systemctl status nginx --no-pager | head -10
"

echo ""
echo "3️⃣ Verificando permissões..."
ssh "$SERVER" "
    echo 'Permissões do diretório:'
    ls -ld $REMOTE_PATH
    echo ''
    echo 'Proprietário dos arquivos:'
    ls -lah $REMOTE_PATH/ | head -5
"

echo ""
echo "4️⃣ Testando acesso HTTP (porta 8080)..."
ssh "$SERVER" "
    echo 'Testando localhost:8080:'
    curl -I http://localhost:8080/task2026/ 2>&1 | head -10
    echo ''
    echo 'Testando arquivo específico:'
    curl -I http://localhost:8080/task2026/index.html 2>&1 | head -5
    echo ''
    echo 'Verificando se porta 8080 está escutando:'
    netstat -tulpn | grep :8080 || ss -tulpn | grep :8080
"

echo ""
echo "=========================================="
echo "✅ Verificação concluída!"
echo "=========================================="
