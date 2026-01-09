#!/bin/bash

# Script rápido para configurar o MCP do Supabase no Cursor usando URL direta
# Execute: bash configurar_mcp_rapido.sh

echo "🚀 Configurando MCP do Supabase no Cursor (método rápido)..."
echo ""

# Caminho do arquivo de configuração do Cursor
CURSOR_MCP_FILE="$HOME/Library/Application Support/Cursor/mcp.json"
CONFIG_TEMPLATE="mcp_supabase_config.json"

# Verificar se o template existe
if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "❌ Arquivo de template não encontrado: $CONFIG_TEMPLATE"
    exit 1
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
    
    # Mesclar com configuração existente
    echo "🔄 Mesclando com configuração existente..."
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
with open("$CONFIG_TEMPLATE", "r") as f:
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
    cp "$CONFIG_TEMPLATE" "$CURSOR_MCP_FILE"
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
echo "📄 Conteúdo:"
cat "$CURSOR_MCP_FILE" | python3 -m json.tool
echo ""











