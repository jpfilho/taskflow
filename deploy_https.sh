#!/bin/bash

# Script para fazer upload e executar configuração HTTPS no servidor

SERVER="root@212.85.0.249"
SCRIPT_NAME="configurar_https_com_supabase.sh"

echo "=========================================="
echo "Deploy: Configurar HTTPS"
echo "=========================================="
echo ""

# Verificar se o script existe localmente
if [ ! -f "$SCRIPT_NAME" ]; then
    echo "❌ Arquivo $SCRIPT_NAME não encontrado!"
    exit 1
fi

# Fazer upload do script
echo "📤 Fazendo upload do script para o servidor..."
scp "$SCRIPT_NAME" "$SERVER:/root/"

if [ $? -eq 0 ]; then
    echo "✅ Upload concluído!"
    echo ""
    echo "🔧 Para executar no servidor, conecte via SSH:"
    echo "   ssh $SERVER"
    echo ""
    echo "   E execute:"
    echo "   bash $SCRIPT_NAME"
    echo ""
    echo "   OU execute diretamente:"
    echo "   ssh $SERVER 'bash -s' < $SCRIPT_NAME"
    echo ""
    
    read -p "Deseja executar o script agora? (s/n): " executar
    
    if [ "$executar" = "s" ] || [ "$executar" = "S" ]; then
        echo ""
        echo "🚀 Executando script no servidor..."
        ssh "$SERVER" "bash $SCRIPT_NAME"
    fi
else
    echo "❌ Erro ao fazer upload!"
    exit 1
fi
