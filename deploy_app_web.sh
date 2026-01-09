#!/bin/bash

# ============================================
# Script de Deploy da Aplicação Flutter Web
# ============================================
# Este script automatiza o build e deploy
# da aplicação Flutter web para produção

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variáveis (ajuste conforme necessário)
PRODUCTION_SERVER="${PRODUCTION_SERVER:-usuario@seu-servidor-hostinger}"
REMOTE_PATH="${REMOTE_PATH:-/var/www/html/task2026}"
BUILD_DIR="build/web"
BASE_HREF="${BASE_HREF:-/}"

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Deploy da Aplicação Flutter Web${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""

# Verificar se Flutter está instalado
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter não encontrado!${NC}"
    echo "   Instale o Flutter: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Verificar versão do Flutter
FLUTTER_VERSION=$(flutter --version | head -1)
echo -e "${BLUE}📱 Flutter: $FLUTTER_VERSION${NC}"
echo ""

# Função para fazer build
build_app() {
    echo -e "${YELLOW}🔨 Fazendo build da aplicação...${NC}"
    echo ""
    
    # Limpar build anterior
    echo -e "${YELLOW}   Limpando build anterior...${NC}"
    flutter clean
    
    # Obter dependências
    echo -e "${YELLOW}   Obtendo dependências...${NC}"
    flutter pub get
    
    # Build para web
    echo -e "${YELLOW}   Compilando para web (release)...${NC}"
    if [ "$BASE_HREF" != "/" ]; then
        flutter build web --release --base-href="$BASE_HREF"
    else
        flutter build web --release
    fi
    
    if [ ! -d "$BUILD_DIR" ]; then
        echo -e "${RED}❌ Erro: Diretório de build não encontrado!${NC}"
        exit 1
    fi
    
    # Verificar tamanho
    SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
    echo ""
    echo -e "${GREEN}✅ Build concluído!${NC}"
    echo -e "${BLUE}   Tamanho: $SIZE${NC}"
    echo -e "${BLUE}   Local: $BUILD_DIR${NC}"
    echo ""
}

# Função para fazer backup no servidor
backup_remote() {
    if [ -z "$PRODUCTION_SERVER" ] || [ "$PRODUCTION_SERVER" = "usuario@seu-servidor-hostinger" ]; then
        echo -e "${YELLOW}⚠️  Servidor não configurado, pulando backup${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}📦 Fazendo backup no servidor...${NC}"
    
    ssh "$PRODUCTION_SERVER" "
        if [ -d '$REMOTE_PATH' ]; then
            BACKUP_DIR='${REMOTE_PATH}_backup_$(date +%Y%m%d_%H%M%S)'
            sudo cp -r '$REMOTE_PATH' \"\$BACKUP_DIR\"
            echo '✅ Backup criado: \$BACKUP_DIR'
        else
            echo '⚠️  Diretório não existe, criando novo...'
            sudo mkdir -p '$REMOTE_PATH'
        fi
    " || echo -e "${YELLOW}⚠️  Erro ao fazer backup (continuando...)${NC}"
    echo ""
}

# Função para transferir arquivos
transfer_files() {
    if [ -z "$PRODUCTION_SERVER" ] || [ "$PRODUCTION_SERVER" = "usuario@seu-servidor-hostinger" ]; then
        echo -e "${YELLOW}⚠️  Servidor não configurado${NC}"
        echo ""
        echo -e "${BLUE}Para configurar, execute:${NC}"
        echo "  export PRODUCTION_SERVER=usuario@seu-servidor-hostinger"
        echo "  export REMOTE_PATH=/var/www/html/task2026"
        echo ""
        echo -e "${YELLOW}Ou copie manualmente:${NC}"
        echo "  scp -r $BUILD_DIR/* $PRODUCTION_SERVER:$REMOTE_PATH/"
        return 1
    fi
    
    echo -e "${YELLOW}📤 Transferindo arquivos para o servidor...${NC}"
    
    # Criar diretório remoto se não existir
    ssh "$PRODUCTION_SERVER" "sudo mkdir -p $REMOTE_PATH"
    
    # Transferir arquivos
    rsync -avz --delete \
        --exclude='.DS_Store' \
        "$BUILD_DIR/" \
        "$PRODUCTION_SERVER:$REMOTE_PATH/" || {
        echo -e "${YELLOW}⚠️  rsync não disponível, usando scp...${NC}"
        scp -r "$BUILD_DIR"/* "$PRODUCTION_SERVER:$REMOTE_PATH/"
    }
    
    # Ajustar permissões
    ssh "$PRODUCTION_SERVER" "sudo chown -R www-data:www-data $REMOTE_PATH && sudo chmod -R 755 $REMOTE_PATH"
    
    echo -e "${GREEN}✅ Arquivos transferidos!${NC}"
    echo ""
}

# Função para verificar deploy
verify_deploy() {
    if [ -z "$PRODUCTION_SERVER" ] || [ "$PRODUCTION_SERVER" = "usuario@seu-servidor-hostinger" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}🔍 Verificando deploy...${NC}"
    
    # Verificar se index.html existe
    ssh "$PRODUCTION_SERVER" "test -f $REMOTE_PATH/index.html && echo '✅ index.html encontrado' || echo '❌ index.html não encontrado'"
    
    # Listar alguns arquivos
    echo ""
    echo -e "${BLUE}Arquivos no servidor:${NC}"
    ssh "$PRODUCTION_SERVER" "ls -lh $REMOTE_PATH | head -10"
    echo ""
}

# Menu principal
show_menu() {
    echo "Escolha uma opção:"
    echo "1) Build apenas (local)"
    echo "2) Build + Deploy (completo)"
    echo "3) Deploy apenas (já tem build)"
    echo "4) Verificar build local"
    echo "5) Limpar build"
    echo "6) Sair"
    echo ""
    read -p "Opção: " option
    
    case $option in
        1)
            build_app
            echo ""
            echo -e "${GREEN}✅ Build concluído!${NC}"
            echo -e "${YELLOW}Próximo passo: Execute a opção 3 para fazer deploy${NC}"
            ;;
        2)
            build_app
            backup_remote
            transfer_files
            verify_deploy
            echo ""
            echo -e "${GREEN}✅ Deploy concluído com sucesso!${NC}"
            ;;
        3)
            if [ ! -d "$BUILD_DIR" ]; then
                echo -e "${RED}❌ Build não encontrado! Execute a opção 1 primeiro.${NC}"
                return
            fi
            backup_remote
            transfer_files
            verify_deploy
            echo ""
            echo -e "${GREEN}✅ Deploy concluído!${NC}"
            ;;
        4)
            if [ -d "$BUILD_DIR" ]; then
                echo -e "${GREEN}✅ Build encontrado:${NC}"
                echo -e "${BLUE}   Local: $BUILD_DIR${NC}"
                SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
                echo -e "${BLUE}   Tamanho: $SIZE${NC}"
                echo ""
                echo "Arquivos principais:"
                ls -lh "$BUILD_DIR" | head -10
            else
                echo -e "${RED}❌ Build não encontrado!${NC}"
            fi
            ;;
        5)
            echo -e "${YELLOW}🧹 Limpando build...${NC}"
            flutter clean
            rm -rf "$BUILD_DIR"
            echo -e "${GREEN}✅ Limpeza concluída!${NC}"
            ;;
        6)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opção inválida!${NC}"
            ;;
    esac
}

# Verificar se está no diretório do projeto
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Execute este script no diretório raiz do projeto Flutter!${NC}"
    exit 1
fi

# Loop do menu
while true; do
    show_menu
    echo ""
done
