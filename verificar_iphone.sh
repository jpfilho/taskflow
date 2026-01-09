#!/bin/bash

echo "=========================================="
echo "🔍 Verificando iPhone Físico"
echo "=========================================="
echo ""

echo "📱 Verificando dispositivos via Flutter..."
flutter devices --device-timeout 30

echo ""
echo "📱 Verificando dispositivos via Xcode..."
xcrun devicectl list devices 2>/dev/null | grep -i "iphone" | grep -v "Simulator" || echo "Nenhum iPhone físico encontrado via devicectl"

echo ""
echo "=========================================="
echo "Status:"
echo "=========================================="
echo ""

# Verificar se há iPhone físico disponível
IPHONE_PHYSICAL=$(flutter devices --device-timeout 10 2>/dev/null | grep -i "iphone" | grep -v "simulator" | grep -v "Simulator")

if [ ! -z "$IPHONE_PHYSICAL" ]; then
    echo "✅ iPhone físico detectado!"
    echo ""
    echo "$IPHONE_PHYSICAL"
    echo ""
    DEVICE_ID=$(echo "$IPHONE_PHYSICAL" | awk '{print $5}')
    if [ ! -z "$DEVICE_ID" ]; then
        echo "🚀 Para executar, use:"
        echo "   flutter run -d $DEVICE_ID"
        echo ""
        read -p "Deseja executar agora? (s/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            echo "🚀 Executando no iPhone..."
            flutter run -d "$DEVICE_ID"
        fi
    fi
else
    echo "⚠️  iPhone físico não está disponível ainda."
    echo ""
    echo "📋 Próximos passos:"
    echo "   1. Conecte o iPhone via cabo USB ao Mac"
    echo "   2. Abra o Xcode"
    echo "   3. Window > Devices and Simulators (Cmd+Shift+2)"
    echo "   4. Selecione seu iPhone"
    echo "   5. Marque 'Connect via network'"
    echo "   6. Aguarde o ícone WiFi aparecer"
    echo "   7. Desconecte o cabo USB"
    echo "   8. Execute este script novamente"
    echo ""
    echo "📄 Veja PROXIMOS_PASSOS.md para instruções detalhadas"
fi












