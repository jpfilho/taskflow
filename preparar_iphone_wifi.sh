#!/bin/bash

echo "=========================================="
echo "Preparando iPhone para Conexão WiFi"
echo "=========================================="
echo ""

echo "📱 PASSO 1: Conecte o iPhone via cabo USB ao Mac"
read -p "Pressione ENTER quando o iPhone estiver conectado..."

echo ""
echo "📱 PASSO 2: Verificando se o iPhone está conectado..."
flutter devices

echo ""
echo "📱 PASSO 3: Abra o Xcode e configure a conexão WiFi:"
echo "   1. Abra o Xcode"
echo "   2. Vá em Window > Devices and Simulators (Cmd+Shift+2)"
echo "   3. Selecione seu iPhone na lista"
echo "   4. Marque 'Connect via network'"
echo "   5. Aguarde o ícone de WiFi aparecer"
echo ""
read -p "Pressione ENTER quando tiver configurado no Xcode..."

echo ""
echo "📱 PASSO 4: Verificando Modo Desenvolvedor no iPhone:"
echo "   No iPhone, vá em: Configurações > Privacidade e Segurança > Modo Desenvolvedor"
echo "   Certifique-se de que está ATIVADO"
echo ""
read -p "Pressione ENTER quando o Modo Desenvolvedor estiver ativado..."

echo ""
echo "📱 PASSO 5: Desconecte o cabo USB do iPhone"
read -p "Pressione ENTER quando tiver desconectado o cabo..."

echo ""
echo "🔍 Verificando dispositivos disponíveis..."
flutter devices --device-timeout 30

echo ""
echo "✅ Se o iPhone aparecer na lista acima, você pode executar:"
echo "   flutter run"
echo ""
echo "Ou especifique o device-id:"
echo "   flutter run -d <device-id>"












