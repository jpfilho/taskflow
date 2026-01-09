#!/bin/bash

# Script para configurar o MCP do Supabase no Cursor
# Execute: bash configurar_mcp_supabase.sh

echo "🚀 Configurando MCP do Supabase no Cursor..."
echo ""

# Caminho do arquivo de configuração do Cursor
CURSOR_MCP_FILE="$HOME/Library/Application Support/Cursor/mcp.json"
CONFIG_TEMPLATE="mcp_supabase_config.json"

# Verificar se o Node.js está instalado
if ! command -v node &> /dev/null; then
    echo "❌ Node.js não está instalado!"
    echo "   Instale o Node.js em: https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js encontrado: $(node --version)"

# Verificar se o npm está instalado
if ! command -v npm &> /dev/null; then
    echo "❌ npm não está instalado!"
    exit 1
fi

echo "✅ npm encontrado: $(npm --version)"
echo ""

# Verificar se o template existe
if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "❌ Arquivo de template não encontrado: $CONFIG_TEMPLATE"
    exit 1
fi

# Ler as credenciais do Supabase
echo "📝 Por favor, forneça suas credenciais do Supabase:"
echo ""
read -p "SUPABASE_ANON_KEY: " SUPABASE_ANON_KEY
read -p "SUPABASE_SERVICE_ROLE_KEY (opcional, pressione Enter para pular): " SUPABASE_SERVICE_ROLE_KEY

# Substituir as chaves no template
if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    # Remover a linha do SERVICE_ROLE_KEY se não for fornecida
    sed "s/YOUR_ANON_KEY_HERE/$SUPABASE_ANON_KEY/g" "$CONFIG_TEMPLATE" | \
    sed '/SUPABASE_SERVICE_ROLE_KEY/d' > /tmp/mcp_config.json
else
    sed "s/YOUR_ANON_KEY_HERE/$SUPABASE_ANON_KEY/g" "$CONFIG_TEMPLATE" | \
    sed "s/YOUR_SERVICE_ROLE_KEY_HERE/$SUPABASE_SERVICE_ROLE_KEY/g" > /tmp/mcp_config.json
fi

# Verificar se o diretório do Cursor existe
CURSOR_DIR="$HOME/Library/Application Support/Cursor"
if [ ! -d "$CURSOR_DIR" ]; then
    echo "📁 Criando diretório do Cursor..."
    mkdir -p "$CURSOR_DIR"
fi

# Fazer backup do arquivo existente se houver
if [ -f "$CURSOR_MCP_FILE" ]; then
    echo "💾 Fazendo backup do arquivo existente..."
    cp "$CURSOR_MCP_FILE" "$CURSOR_MCP_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Verificar se já existe configuração do Supabase
if [ -f "$CURSOR_MCP_FILE" ]; then
    # Se o arquivo já existe, mesclar as configurações
    echo "🔄 Mesclando com configuração existente..."
    
    # Usar Python para mesclar JSON
    python3 << EOF
import json
import sys

# Ler configuração existente
try:
    with open("$CURSOR_MCP_FILE", "r") as f:
        existing = json.load(f)
except:
    existing = {"mcpServers": {}}

# Ler nova configuração
with open("/tmp/mcp_config.json", "r") as f:
    new_config = json.load(f)

# Mesclar
if "mcpServers" not in existing:
    existing["mcpServers"] = {}

existing["mcpServers"]["supabase"] = new_config["mcpServers"]["supabase"]

# Salvar
with open("$CURSOR_MCP_FILE", "w") as f:
    json.dump(existing, f, indent=2)

print("✅ Configuração mesclada com sucesso!")
EOF
else
    # Se não existe, copiar o template
    echo "📋 Criando novo arquivo de configuração..."
    cp /tmp/mcp_config.json "$CURSOR_MCP_FILE"
fi

echo ""
echo "✅ Configuração do MCP do Supabase concluída!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Reinicie o Cursor"
echo "   2. Pressione Cmd+Shift+P e digite 'MCP: List Servers'"
echo "   3. Verifique se o servidor 'supabase' está listado"
echo ""
echo "🔧 Arquivo de configuração: $CURSOR_MCP_FILE"
echo ""











