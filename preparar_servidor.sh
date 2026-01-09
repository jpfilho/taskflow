#!/bin/bash

# Script para executar NO SERVIDOR (via SSH)
# Execute: bash preparar_servidor.sh

REMOTE_PATH="/var/www/html/task2026"

echo "=========================================="
echo "Preparando servidor para deploy"
echo "=========================================="
echo ""

# Criar diretório
echo "📁 Criando diretório: $REMOTE_PATH"
mkdir -p "$REMOTE_PATH"
chmod 755 "$REMOTE_PATH"

# Verificar se Nginx está instalado
if command -v nginx &> /dev/null; then
    echo "✅ Nginx encontrado"
    NGINX_USER=$(ps aux | grep nginx | grep -v grep | head -1 | awk '{print $1}' || echo "www-data")
    echo "   Usuário do Nginx: $NGINX_USER"
    chown -R "$NGINX_USER:$NGINX_USER" "$REMOTE_PATH"
elif command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
    echo "✅ Apache encontrado"
    chown -R www-data:www-data "$REMOTE_PATH"
else
    echo "⚠️  Servidor web não identificado, usando www-data"
    chown -R www-data:www-data "$REMOTE_PATH"
fi

# Ajustar permissões
chmod -R 755 "$REMOTE_PATH"

echo ""
echo "✅ Diretório criado e configurado!"
echo "   Caminho: $REMOTE_PATH"
echo ""
echo "📋 Próximo passo:"
echo "   Do seu computador local, execute:"
echo "   scp -r build/web/* root@212.85.0.249:$REMOTE_PATH/"
echo ""
