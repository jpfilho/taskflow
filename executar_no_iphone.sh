#!/bin/bash

echo "🔍 Procurando dispositivos iOS..."
flutter devices --device-timeout 30

echo ""
echo "📱 Dispositivos encontrados acima."
echo ""
echo "Para executar no iPhone físico, use:"
echo "  flutter run -d <device-id>"
echo ""
echo "Ou se houver apenas um dispositivo iOS:"
echo "  flutter run"
echo ""

# Tentar encontrar device-id do iPhone físico (não simulador)
DEVICE_ID=$(flutter devices --device-timeout 10 2>/dev/null | grep -i "iphone" | grep -v "simulator" | grep -v "Simulator" | awk '{print $5}' | head -1)

if [ ! -z "$DEVICE_ID" ]; then
    echo "✅ iPhone físico encontrado: $DEVICE_ID"
    echo ""
    read -p "Deseja executar agora? (s/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo "🚀 Executando no iPhone..."
        flutter run -d "$DEVICE_ID"
    fi
else
    echo "⚠️  Nenhum iPhone físico encontrado."
    echo ""
    echo "Certifique-se de que:"
    echo "  1. iPhone está conectado via WiFi (configure no Xcode primeiro)"
    echo "  2. Modo Desenvolvedor está ativado no iPhone"
    echo "  3. iPhone e Mac estão na mesma rede WiFi"
fi
