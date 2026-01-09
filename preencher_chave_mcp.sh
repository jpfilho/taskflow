#!/bin/bash

# Script simples para preencher a chave anon do Supabase no MCP
# Execute: bash preencher_chave_mcp.sh

CURSOR_MCP_FILE="$HOME/Library/Application Support/Cursor/mcp.json"

echo "🔑 Preenchendo chave anon do Supabase no MCP..."
echo ""
echo "📝 Por favor, cole sua chave anon do Supabase:"
echo "   (Encontre em: https://srv750497.hstgr.cloud/project/default/settings/api)"
echo ""
read -p "SUPABASE_ANON_KEY: " SUPABASE_ANON_KEY

if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ Chave não fornecida. Cancelando..."
    exit 1
fi

# Atualizar apenas a chave anon
python3 << EOF
import json
import os

# Ler configuração existente
with open("$CURSOR_MCP_FILE", "r") as f:
    config = json.load(f)

# Atualizar apenas a chave anon
if "mcpServers" in config and "supabase" in config["mcpServers"]:
    if "env" in config["mcpServers"]["supabase"]:
        config["mcpServers"]["supabase"]["env"]["SUPABASE_ANON_KEY"] = "$SUPABASE_ANON_KEY"
    else:
        config["mcpServers"]["supabase"]["env"] = {
            "SUPABASE_URL": "https://srv750497.hstgr.cloud",
            "SUPABASE_ANON_KEY": "$SUPABASE_ANON_KEY"
        }
else:
    print("❌ Configuração do Supabase não encontrada!")
    exit(1)

# Salvar
with open("$CURSOR_MCP_FILE", "w") as f:
    json.dump(config, f, indent=2)

print("✅ Chave anon atualizada com sucesso!")
EOF

echo ""
echo "✅ Configuração atualizada!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Reinicie o Cursor completamente"
echo "   2. Verifique se o servidor 'supabase' está funcionando"
echo ""










