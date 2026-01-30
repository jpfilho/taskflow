#!/bin/bash

# ============================================
# Script de Build para iOS
# ============================================
# Este script incrementa o build number e faz o build para iOS

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Build iOS - Task Flow${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""

# Ler a versão atual do pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
VERSION_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

# Garantir que BUILD_NUMBER exista
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER=0
fi

IOS_DIR="ios"

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

# Garantir pods atualizados e dSYM habilitado
echo -e "${YELLOW}📦 Instalando pods (gera dSYM)...${NC}"
(cd "$IOS_DIR" && pod install --repo-update)
echo -e "${GREEN}✅ Pods instalados${NC}"
echo ""

# Verificar dispositivos iOS disponíveis
echo -e "${YELLOW}📱 Verificando dispositivos iOS disponíveis...${NC}"
flutter devices | grep -i ios || echo -e "${YELLOW}⚠️  Nenhum dispositivo iOS conectado${NC}"
echo ""

# Menu de opções
echo "Escolha uma opção:"
echo "1) Build para desenvolvimento (Debug)"
echo "2) Build para release (Release)"
echo "3) Build e abrir no Xcode"
echo "4) Apenas atualizar versão (sem build)"
echo "5) Cancelar"
echo ""
read -p "Opção: " option

case $option in
    1)
        echo -e "${YELLOW}🔨 Fazendo build Debug...${NC}"
        flutter build ios --debug --build-number ${NEW_BUILD_NUMBER}
        echo -e "${GREEN}✅ Build Debug concluído!${NC}"
        echo -e "${BLUE}📱 Para executar no dispositivo:${NC}"
        echo -e "${BLUE}   flutter run -d <device-id>${NC}"
        ;;
    2)
        echo -e "${YELLOW}🔨 Fazendo build Release (IPA)...${NC}"
        flutter build ipa --release --build-number ${NEW_BUILD_NUMBER}
        echo -e "${GREEN}✅ Build Release concluído!${NC}"
        echo -e "${BLUE}📦 IPA gerado em: build/ios/ipa/${NC}"
        echo -e "${BLUE}🧾 Build number usado: ${NEW_BUILD_NUMBER}${NC}"
        ;;
    3)
        echo -e "${YELLOW}🔨 Fazendo build e abrindo no Xcode...${NC}"
        flutter build ios --release --build-number ${NEW_BUILD_NUMBER}
        echo -e "${GREEN}✅ Build concluído!${NC}"
        echo -e "${YELLOW}📱 Abrindo Xcode...${NC}"
        open ios/Runner.xcworkspace
        echo -e "${GREEN}✅ Xcode aberto!${NC}"
        echo -e "${BLUE}💡 No Xcode:${NC}"
        echo -e "${BLUE}   1. Selecione 'Any iOS Device' como destino${NC}"
        echo -e "${BLUE}   2. Product > Archive${NC}"
        echo -e "${BLUE}   3. Distribuir App${NC}"
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
