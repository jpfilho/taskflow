#!/bin/bash
# ============================================
# INSTALAR NODE.JS E DEPENDENCIAS
# ============================================

cd /root/telegram-webhook

# Verificar Node.js
if ! command -v node &> /dev/null; then
    echo "Instalando Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

echo "Node: $(node --version)"
echo "NPM: $(npm --version)"

# Instalar pacotes
echo "Instalando pacotes NPM..."
npm install

echo "Dependencias instaladas!"
