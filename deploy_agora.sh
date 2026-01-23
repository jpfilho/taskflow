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
# Reutilizar conexão SSH para evitar pedir senha várias vezes
SSH_OPTS="-o ControlMaster=auto -o ControlPath=~/.ssh/cm-%r@%h:%p -o ControlPersist=300"

echo "=========================================="
echo "Deploy da Aplicação para Produção"
echo "=========================================="
echo ""
echo "Servidor: $SERVER"
echo "Caminho remoto: $REMOTE_PATH"
echo ""

# Verificar se deve fazer build
DO_BUILD=true
if [ "$1" == "--no-build" ]; then
    DO_BUILD=false
    echo "⚠️  Pulando build (usando build existente)"
fi

# Fazer build se necessário
if [ "$DO_BUILD" = true ]; then
    echo "🔨 Fazendo build da aplicação..."
    echo ""
    
    # Limpar build anterior
    echo "   🧹 Limpando build anterior..."
    flutter clean > /dev/null 2>&1 || true
    
    # Obter dependências
    echo "   📦 Obtendo dependências..."
    flutter pub get > /dev/null 2>&1
    
    # Build para web
    echo "   ⚙️  Compilando para web (release)..."
    # Usar build web com base href configurado
    flutter build web --release --base-href="/task2026/"
    
    if [ ! -d "build/web" ]; then
        echo "❌ Erro: Build falhou! Diretório build/web não encontrado!"
        exit 1
    fi
    
    echo "   ✅ Build concluído!"
    echo ""
fi

# Verificar se build/web existe
if [ ! -d "build/web" ]; then
    echo "❌ Erro: Diretório build/web não encontrado!"
    echo "   Execute primeiro: flutter build web --release"
    exit 1
fi

# Criar arquivo de versão com timestamp e aplicar cache-busting no index.html
BUILD_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
VERSION_FILE="build/web/version.txt"
echo "$BUILD_TIMESTAMP" > "$VERSION_FILE"
echo "📝 Versão do build: $BUILD_TIMESTAMP"

# Injetar querystring de versão para evitar cache do navegador
echo "🔄 Aplicando cache-busting em index.html e service worker..."
perl -pi -e "s/main.dart.js/main.dart.js?v=$BUILD_TIMESTAMP/g; s/flutter.js/flutter.js?v=$BUILD_TIMESTAMP/g; s/canvaskit.wasm/canvaskit.wasm?v=$BUILD_TIMESTAMP/g; s/flutter_service_worker.js/flutter_service_worker.js?v=$BUILD_TIMESTAMP/g" build/web/index.html || true

# Garantir que o registro do service worker use a versão (em flutter.js também)
if [ -f "build/web/flutter.js" ]; then
  perl -pi -e "s/flutter_service_worker.js/flutter_service_worker.js?v=$BUILD_TIMESTAMP/g" build/web/flutter.js || true

  # 🚫 Desabilitar registro do service worker para evitar cache agressivo
  perl -0777 -pi -e "s/navigator\\.serviceWorker\\.register\\([^;]*;//g" build/web/flutter.js || true
fi

# Opcional: remover o service worker gerado (evita SW legado)
if [ -f "build/web/flutter_service_worker.js" ]; then
  echo "// Service worker desabilitado no deploy" > build/web/flutter_service_worker.js
fi

# (Opcional) Se existir main.dart.js plain-text, reforçar o versionamento do SW lá também
if [ -f "build/web/main.dart.js" ]; then
  perl -pi -e "s/flutter_service_worker.js/flutter_service_worker.js?v=$BUILD_TIMESTAMP/g" build/web/main.dart.js || true
fi

# Forçar invalidação do service worker e caches do Flutter
if [ -f "build/web/flutter_service_worker.js" ]; then
  perl -pi -e "s/CACHE_NAME = 'flutter-app-cache'/CACHE_NAME = 'flutter-app-cache-$BUILD_TIMESTAMP'/g; s/TEMP = 'flutter-temp-cache'/TEMP = 'flutter-temp-cache-$BUILD_TIMESTAMP'/g" build/web/flutter_service_worker.js || true
fi

# Criar regras de cache (Apache) para garantir no-store em HTML e SW
cat > build/web/.htaccess <<'EOF'
# Forçar não-cache para HTML e service worker
<FilesMatch "^(index\.html|flutter_service_worker\.js|version\.txt)$">
  Header set Cache-Control "no-store, no-cache, must-revalidate, max-age=0"
</FilesMatch>

# Ativos estáticos podem usar cache longo
<FilesMatch "\.(js|css|json|wasm|png|jpg|jpeg|gif|svg|ico)$">
  Header set Cache-Control "public, max-age=31536000, immutable"
</FilesMatch>
EOF

echo ""
echo "📦 Arquivos para deploy:"
du -sh build/web
echo ""

# Criar diretório remoto se não existir
echo "📁 Criando diretório remoto (se necessário)..."
echo "   Executando: ssh $SERVER 'mkdir -p $REMOTE_PATH'"
ssh $SSH_OPTS "$SERVER" "mkdir -p $REMOTE_PATH && chmod 755 $REMOTE_PATH" || {
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
ssh $SSH_OPTS "$SERVER" "
    if [ -d '$REMOTE_PATH' ] && [ \"\$(ls -A $REMOTE_PATH 2>/dev/null)\" ]; then
        BACKUP_DIR='${REMOTE_PATH}_backup_$(date +%Y%m%d_%H%M%S)'
        sudo cp -r '$REMOTE_PATH' \"\$BACKUP_DIR\"
        echo '✅ Backup criado: \$BACKUP_DIR'
    fi
" || echo "⚠️  Não foi possível fazer backup (continuando...)"

# Transferir arquivos
echo ""
echo "📤 Transferindo arquivos..."
echo "   Usando rsync com flags: -avz --progress --delete --checksum"
rsync -avz --progress --delete --checksum -e "ssh $SSH_OPTS" \
    --exclude='.DS_Store' \
    --exclude='.git' \
    build/web/ \
    "$SERVER:$REMOTE_PATH/" || {
    echo ""
    echo "⚠️  rsync falhou, tentando com scp..."
  ssh $SSH_OPTS "$SERVER" "rm -rf $REMOTE_PATH/*" || true
  scp -o ControlMaster=auto -o ControlPath=~/.ssh/cm-%r@%h:%p -o ControlPersist=300 -r build/web/* "$SERVER:$REMOTE_PATH/"
}

# Verificar se os arquivos foram transferidos
echo ""
echo "🔍 Verificando arquivos transferidos..."
REMOTE_VERSION=$(ssh $SSH_OPTS "$SERVER" "cat $REMOTE_PATH/version.txt 2>/dev/null || echo 'N/A'")
if [ "$REMOTE_VERSION" = "$BUILD_TIMESTAMP" ]; then
    echo "   ✅ Versão confirmada no servidor: $REMOTE_VERSION"
else
    echo "   ⚠️  Versão no servidor: $REMOTE_VERSION (esperado: $BUILD_TIMESTAMP)"
fi

# Ajustar permissões
echo ""
echo "🔐 Ajustando permissões..."
ssh $SSH_OPTS "$SERVER" "sudo chown -R www-data:www-data $REMOTE_PATH && sudo chmod -R 755 $REMOTE_PATH" || {
    echo "⚠️  Não foi possível ajustar permissões automaticamente."
    echo "   Ajuste manualmente se necessário."
}

echo ""
echo "✅ Deploy concluído!"
echo ""
echo "🌐 Acesse a aplicação em:"
echo "   http://212.85.0.249:8080/task2026/"
echo "   ou"
echo "   http://taskflowv3.com.br/ (redireciona para http://212.85.0.249:8080/task2026/)"
echo ""
echo "💡 Dica: Se a versão não atualizou no navegador:"
echo "   - Pressione Ctrl+Shift+R (ou Cmd+Shift+R no Mac) para forçar atualização"
echo "   - Ou limpe o cache do navegador"
echo ""
echo "📋 Versão do build: $BUILD_TIMESTAMP"
echo ""