#!/bin/bash

# Script para corrigir a configuração do MCP do Supabase no Cursor
# Execute: bash corrigir_mcp.sh

echo "🔧 Corrigindo configuração do MCP do Supabase..."
echo ""

# Caminho do arquivo de configuração do Cursor
CURSOR_MCP_FILE="$HOME/Library/Application Support/Cursor/mcp.json"

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

# Fazer backup do arquivo existente se houver
if [ -f "$CURSOR_MCP_FILE" ]; then
    echo "💾 Fazendo backup do arquivo existente..."
    cp "$CURSOR_MCP_FILE" "$CURSOR_MCP_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Ler as credenciais do Supabase
echo "📝 Por favor, forneça suas credenciais do Supabase:"
echo "   (Você pode encontrar essas chaves em: https://srv750497.hstgr.cloud/project/default/settings/api)"
echo ""
read -p "SUPABASE_ANON_KEY: " SUPABASE_ANON_KEY
read -p "SUPABASE_SERVICE_ROLE_KEY (opcional, pressione Enter para pular): " SUPABASE_SERVICE_ROLE_KEY

# Criar configuração correta
if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    # Sem service role key
    python3 << EOF
import json
import os

# Ler configuração existente ou criar nova
if os.path.exists("$CURSOR_MCP_FILE"):
    with open("$CURSOR_MCP_FILE", "r") as f:
        config = json.load(f)
else:
    config = {"mcpServers": {}}

# Atualizar configuração do Supabase
if "mcpServers" not in config:
    config["mcpServers"] = {}

config["mcpServers"]["supabase"] = {
    "command": "npx",
    "args": [
        "-y",
        "@supabase/mcp-server-supabase"
    ],
    "env": {
        "SUPABASE_URL": "https://srv750497.hstgr.cloud",
        "SUPABASE_ANON_KEY": "$SUPABASE_ANON_KEY"
    }
}

# Salvar
os.makedirs(os.path.dirname("$CURSOR_MCP_FILE"), exist_ok=True)
with open("$CURSOR_MCP_FILE", "w") as f:
    json.dump(config, f, indent=2)

print("✅ Configuração atualizada com sucesso!")
EOF
else
    # Com service role key
    python3 << EOF
import json
import os

# Ler configuração existente ou criar nova
if os.path.exists("$CURSOR_MCP_FILE"):
    with open("$CURSOR_MCP_FILE", "r") as f:
        config = json.load(f)
else:
    config = {"mcpServers": {}}

# Atualizar configuração do Supabase
if "mcpServers" not in config:
    config["mcpServers"] = {}

config["mcpServers"]["supabase"] = {
    "command": "npx",
    "args": [
        "-y",
        "@supabase/mcp-server-supabase"
    ],
    "env": {
        "SUPABASE_URL": "https://srv750497.hstgr.cloud",
        "SUPABASE_ANON_KEY": "$SUPABASE_ANON_KEY",
        "SUPABASE_SERVICE_ROLE_KEY": "$SUPABASE_SERVICE_ROLE_KEY"
    }
}

# Salvar
os.makedirs(os.path.dirname("$CURSOR_MCP_FILE"), exist_ok=True)
with open("$CURSOR_MCP_FILE", "w") as f:
    json.dump(config, f, indent=2)

print("✅ Configuração atualizada com sucesso!")
EOF
fi

echo ""
echo "✅ Configuração corrigida!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Reinicie o Cursor completamente (feche e abra novamente)"
echo "   2. Pressione Cmd+Shift+P e digite 'MCP: List Servers'"
echo "   3. Verifique se o servidor 'supabase' está listado e funcionando"
echo ""
echo "🔧 Arquivo de configuração: $CURSOR_MCP_FILE"
echo ""










