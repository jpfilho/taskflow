# ⚡ TestFlight - Guia Rápido

## 🎯 Resumo

TestFlight permite distribuir seu app iOS sem cabo USB e sem expiração de 7 dias.

## ✅ Pré-requisito

**Conta Apple Developer** (US$ 99/ano)
- https://developer.apple.com/programs/
- Ativação pode levar algumas horas

## 🚀 Passos Rápidos

### 1. Configurar no Xcode
```bash
open ios/Runner.xcworkspace
```
- Bundle Identifier único (ex: `com.josepereira.task2026`)
- Assinatura: "Automatically manage signing" + seu Team

### 2. Criar Archive
- Xcode > Product > Archive
- Aguarde build completar

### 3. Distribuir
- Organizer > "Distribute App"
- Selecione "App Store Connect"
- Upload

### 4. App Store Connect
- https://appstoreconnect.apple.com
- Criar novo app
- TestFlight > Adicionar build
- Adicionar testadores

### 5. Instalar
- Instalar app "TestFlight" no iPhone
- Login com Apple ID de desenvolvedor
- App aparecerá automaticamente

## 💡 Vantagens

✅ Sem cabo USB
✅ Sem expiração de 7 dias
✅ Até 10.000 testadores
✅ Notificações de atualização
✅ Testes em múltiplos dispositivos

## ⚠️ Importante

- Primeira versão externa: aprovação Apple (24-48h)
- Builds expiram em 90 dias
- Precisa de conta Apple Developer paga







