#!/bin/bash

# ============================================
# Script de Deploy Rápido
# ============================================
# Execute este script para fazer deploy
# dos arquivos build/web/ para o servidor

set -e

# Configurações do servidor
SERVER="root@212.85.0.249"
REMOTE_PATH="/var/www/html/task2026"

echo "=========================================="
echo "Deploy da Aplicação para Produção"
echo "=========================================="
echo ""
echo "Servidor: $SERVER"
echo "Caminho remoto: $REMOTE_PATH"
echo ""

# Verificar se build/web existe
if [ ! -d "build/web" ]; then
    echo "❌ Erro: Diretório build/web não encontrado!"
    echo "   Execute primeiro: flutter build web --release"
    exit 1
fi

echo "📦 Arquivos para deploy:"
du -sh build/web
echo ""

# Criar diretório remoto se não existir
echo "📁 Criando diretório remoto (se necessário)..."
echo "   Executando: ssh $SERVER 'mkdir -p $REMOTE_PATH'"
ssh "$SERVER" "mkdir -p $REMOTE_PATH && chmod 755 $REMOTE_PATH" || {
    echo ""
    echo "⚠️  Não foi possível criar o diretório automaticamente."
    echo ""
    echo "📝 Execute manualmente no servidor:"
    echo "   ssh $SERVER"
    echo "   mkdir -p $REMOTE_PATH"
    echo "   chmod 755 $REMOTE_PATH"
    echo ""
    read -p "Pressione Enter após criar o diretório para continuar..."
}

# Fazer backup do que já existe
echo ""
echo "💾 Fazendo backup do conteúdo atual..."
ssh "$SERVER" "
    if [ -d '$REMOTE_PATH' ] && [ \"\$(ls -A $REMOTE_PATH 2>/dev/null)\" ]; then
        BACKUP_DIR='${REMOTE_PATH}_backup_$(date +%Y%m%d_%H%M%S)'
        sudo cp -r '$REMOTE_PATH' \"\$BACKUP_DIR\"
        echo '✅ Backup criado: \$BACKUP_DIR'
    fi
" || echo "⚠️  Não foi possível fazer backup (continuando...)"

# Transferir arquivos
echo ""
echo "📤 Transferindo arquivos..."
rsync -avz --progress --delete \
    --exclude='.DS_Store' \
    build/web/ \
    "$SERVER:$REMOTE_PATH/" || {
    echo ""
    echo "⚠️  rsync falhou, tentando com scp..."
    scp -r build/web/* "$SERVER:$REMOTE_PATH/"
}

# Ajustar permissões
echo ""
echo "🔐 Ajustando permissões..."
ssh "$SERVER" "sudo chown -R www-data:www-data $REMOTE_PATH && sudo chmod -R 755 $REMOTE_PATH" || {
    echo "⚠️  Não foi possível ajustar permissões automaticamente."
    echo "   Ajuste manualmente se necessário."
}

echo ""
echo "✅ Deploy concluído!"
echo ""
echo "🌐 Acesse a aplicação em:"
echo "   http://212.85.0.249/task2026/"
echo "   ou"
echo "   https://seu-dominio.com.br/task2026/"
echo ""
