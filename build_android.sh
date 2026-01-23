#!/bin/bash

# ============================================
# Script de Build para Android (APK/AppBundle)
# ============================================
# Incrementa o build number e gera APK ou AAB.

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Build Android - Task Flow${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""

# Ler a versão atual do pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
VERSION_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

echo -e "${BLUE}Versão atual: ${CURRENT_VERSION}${NC}"
echo -e "${BLUE}  - Versão: ${VERSION_NUMBER}${NC}"
echo -e "${BLUE}  - Build: ${BUILD_NUMBER}${NC}"
echo ""

# Incrementar build number
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${VERSION_NUMBER}+${NEW_BUILD_NUMBER}"

echo -e "${YELLOW}📦 Incrementando build number...${NC}"
echo -e "${YELLOW}  Novo build: ${NEW_BUILD_NUMBER}${NC}"

# Atualizar pubspec.yaml
sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml

echo -e "${GREEN}✅ Versão atualizada para: ${NEW_VERSION}${NC}"
echo ""

# Limpar build anterior
echo -e "${YELLOW}🧹 Limpando builds anteriores...${NC}"
flutter clean
echo -e "${GREEN}✅ Limpeza concluída${NC}"
echo ""

# Obter dependências
echo -e "${YELLOW}📥 Obtendo dependências...${NC}"
flutter pub get
echo -e "${GREEN}✅ Dependências obtidas${NC}"
echo ""

# Verificar dispositivos Android disponíveis
echo -e "${YELLOW}🤖 Verificando dispositivos Android disponíveis...${NC}"
flutter devices | grep -i android || echo -e "${YELLOW}⚠️  Nenhum dispositivo Android conectado${NC}"
echo ""

# Menu de opções
echo "Escolha uma opção:"
echo "1) Build APK Debug"
echo "2) Build APK Release"
echo "3) Build App Bundle (AAB Release)"
echo "4) Apenas atualizar versão (sem build)"
echo "5) Cancelar"
echo ""
read -p "Opção: " option

case $option in
    1)
        echo -e "${YELLOW}🔨 Fazendo build APK Debug...${NC}"
        flutter build apk --debug
        echo -e "${GREEN}✅ APK Debug gerado em: build/app/outputs/flutter-apk/app-debug.apk${NC}"
        ;;
    2)
        echo -e "${YELLOW}🔨 Fazendo build APK Release...${NC}"
        flutter build apk --release
        echo -e "${GREEN}✅ APK Release gerado em: build/app/outputs/flutter-apk/app-release.apk${NC}"
        ;;
    3)
        echo -e "${YELLOW}🔨 Fazendo build App Bundle (AAB Release)...${NC}"
        flutter build appbundle --release
        echo -e "${GREEN}✅ App Bundle gerado em: build/app/outputs/bundle/release/app-release.aab${NC}"
        ;;
    4)
        echo -e "${GREEN}✅ Versão atualizada para: ${NEW_VERSION}${NC}"
        echo -e "${YELLOW}⚠️  Build não foi executado${NC}"
        ;;
    5)
        echo -e "${YELLOW}❌ Operação cancelada${NC}"
        # Reverter mudança no pubspec.yaml
        sed -i '' "s/^version: .*/version: ${CURRENT_VERSION}/" pubspec.yaml
        echo -e "${GREEN}✅ Versão revertida para: ${CURRENT_VERSION}${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Opção inválida!${NC}"
        # Reverter mudança no pubspec.yaml
        sed -i '' "s/^version: .*/version: ${CURRENT_VERSION}/" pubspec.yaml
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}✅ Processo concluído!${NC}"
echo -e "${GREEN}===========================================${NC}"
