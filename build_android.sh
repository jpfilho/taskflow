#!/bin/bash

# ============================================
# Script de Build para Android
# ============================================
# Incrementa o build number e faz build APK ou App Bundle (AAB)
# Uso: ./build_android.sh
#      ./build_android.sh --no-clean   (pula flutter clean)
#      ./build_android.sh --no-version (não incrementa build number)

set -e

# Configurar JAVA_HOME para Java 21 (Homebrew) para resolver incompatibilidade do Java 25 com Gradle/Kotlin
if [[ -d "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo -e "${BLUE}☕ Usando Java em: $JAVA_HOME${NC}"
  java -version
fi


# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Argumentos
NO_CLEAN=false
NO_VERSION=false
for arg in "$@"; do
  case $arg in
    --no-clean)   NO_CLEAN=true ;;
    --no-version) NO_VERSION=true ;;
  esac
done

# sed in-place: macOS usa sed -i '', Linux usa sed -i
sed_inplace() {
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Build Android - Task Flow${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""

# Ler versão do pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
VERSION_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER=0
fi

NEW_BUILD_NUMBER=$BUILD_NUMBER
NEW_VERSION="$CURRENT_VERSION"

echo -e "${BLUE}Versão atual: ${CURRENT_VERSION}${NC}"
echo -e "${BLUE}  - Versão: ${VERSION_NUMBER}${NC}"
echo -e "${BLUE}  - Build:  ${BUILD_NUMBER}${NC}"
echo ""

# Incrementar build number (a menos que --no-version)
if [[ "$NO_VERSION" != "true" ]]; then
  NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
  NEW_VERSION="${VERSION_NUMBER}+${NEW_BUILD_NUMBER}"
  echo -e "${YELLOW}📦 Incrementando build number -> ${NEW_BUILD_NUMBER}${NC}"
  sed_inplace "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
  echo -e "${GREEN}✅ Versão atualizada para: ${NEW_VERSION}${NC}"
  echo ""
fi

# Limpeza (a menos que --no-clean)
if [[ "$NO_CLEAN" != "true" ]]; then
  echo -e "${YELLOW}🧹 Limpando build anterior...${NC}"
  flutter clean
  echo -e "${GREEN}✅ Limpeza concluída${NC}"
  echo ""
else
  echo -e "${YELLOW}⚠️  Pulando limpeza (--no-clean)${NC}"
  echo ""
fi

# Dependências
echo -e "${YELLOW}📥 Obtendo dependências...${NC}"
flutter pub get
echo -e "${GREEN}✅ Dependências obtidas${NC}"
echo ""

# Menu
echo "Escolha uma opção:"
echo "1) APK Debug (testes)"
echo "2) APK Release (instalação direta)"
echo "3) App Bundle Release (Play Store / AAB)"
echo "4) Apenas atualizar versão (sem build)"
echo "5) Cancelar"
echo ""
read -p "Opção: " option

case $option in
  1)
    echo -e "${YELLOW}🔨 Fazendo build APK Debug...${NC}"
    flutter build apk --debug --build-number "${NEW_BUILD_NUMBER}"
    echo -e "${GREEN}✅ APK Debug concluído!${NC}"
    echo -e "${BLUE}📦 build/app/outputs/flutter-apk/app-debug.apk${NC}"
    ;;
  2)
    echo -e "${YELLOW}🔨 Fazendo build APK Release...${NC}"
    flutter build apk --release --build-number "${NEW_BUILD_NUMBER}"
    APK="build/app/outputs/flutter-apk/app-release.apk"
    if [[ -f "$APK" ]]; then
      SIZE=$(du -h "$APK" | cut -f1)
      echo -e "${GREEN}✅ APK Release concluído!${NC}"
      echo -e "${BLUE}📦 $APK ($SIZE)${NC}"
    fi
    ;;
  3)
    echo -e "${YELLOW}🔨 Fazendo build App Bundle (AAB) para Play Store...${NC}"
    flutter build appbundle --release --build-number "${NEW_BUILD_NUMBER}"
    AAB="build/app/outputs/bundle/release/app-release.aab"
    if [[ -f "$AAB" ]]; then
      SIZE=$(du -h "$AAB" | cut -f1)
      echo -e "${GREEN}✅ App Bundle concluído!${NC}"
      echo -e "${BLUE}📦 $AAB ($SIZE)${NC}"
      echo -e "${BLUE}   Use este arquivo para enviar à Play Store.${NC}"
    fi
    ;;
  4)
    echo -e "${GREEN}✅ Versão atualizada para: ${NEW_VERSION}${NC}"
    echo -e "${YELLOW}⚠️  Build não foi executado${NC}"
    ;;
  5)
    echo -e "${YELLOW}❌ Operação cancelada${NC}"
    if [[ "$NO_VERSION" != "true" && "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
      sed_inplace "s/^version: .*/version: ${CURRENT_VERSION}/" pubspec.yaml
      echo -e "${GREEN}✅ Versão revertida para: ${CURRENT_VERSION}${NC}"
    fi
    exit 0
    ;;
  *)
    echo -e "${RED}❌ Opção inválida!${NC}"
    if [[ "$NO_VERSION" != "true" && "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
      sed_inplace "s/^version: .*/version: ${CURRENT_VERSION}/" pubspec.yaml
      echo -e "${GREEN}✅ Versão revertida para: ${CURRENT_VERSION}${NC}"
    fi
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}✅ Processo concluído!${NC}"
echo -e "${GREEN}===========================================${NC}"
echo -e "${BLUE}Versão do build: ${NEW_VERSION} (build ${NEW_BUILD_NUMBER})${NC}"
echo ""
