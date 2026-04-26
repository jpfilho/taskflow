#!/bin/bash
set -e

echo "🧹 Limpando projeto Flutter..."
flutter clean

echo "📦 Obtendo dependências..."
flutter pub get

echo "🗑️  Limpando DerivedData do Runner..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

echo "🧼 Limpando Pods..."
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
cd ios
rm -rf Pods
rm -rf Podfile.lock
rm -rf Runner.xcworkspace
# Tenta deintegrate, mas não para se falhar
pod deintegrate || echo "⚠️  Aviso: pod deintegrate falhou (continuando...)"
pod install

echo "✅ Limpeza completa! Tente fazer o build novamente."
