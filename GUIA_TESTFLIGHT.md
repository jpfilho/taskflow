# 🚀 Guia Completo: Publicar no TestFlight

## ✅ Pré-requisitos

1. **Conta Apple Developer** (US$ 99/ano)
   - Acesse: https://developer.apple.com/programs/
   - Faça login e assine o programa
   - Aguarde a ativação (pode levar algumas horas)

2. **App Store Connect**
   - Acesse: https://appstoreconnect.apple.com
   - Use a mesma Apple ID da conta desenvolvedor

## 📱 Passo 1: Preparar o App para Distribuição

### 1.1 Configurar Bundle Identifier Único

1. Abra o Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Selecione o projeto "Runner" > Target "Runner" > "Signing & Capabilities"
3. Altere o **Bundle Identifier** para algo único:
   - Exemplo: `com.josepereira.task2026`
   - Deve ser único e não pode estar em uso por outro app

### 1.2 Configurar Assinatura para Distribuição

1. No Xcode, aba "Signing & Capabilities"
2. Marque **"Automatically manage signing"**
3. Selecione seu **Team** (sua conta Apple Developer)
4. Deve aparecer um check verde ✅

## 🏗️ Passo 2: Criar Build para TestFlight

### 2.1 Atualizar Version e Build Number

1. No Xcode, selecione o projeto "Runner"
2. Aba "General"
3. Atualize:
   - **Version**: `1.0.0` (ou a versão desejada)
   - **Build**: `1` (incremente a cada build)

### 2.2 Criar Archive

1. No Xcode, selecione **"Any iOS Device"** no seletor (não um dispositivo específico)
2. Vá em **Product > Archive**
3. Aguarde o build completar (pode levar alguns minutos)
4. O **Organizer** abrirá automaticamente

### 2.3 Validar o Archive

1. No Organizer, selecione o archive criado
2. Clique em **"Validate App"**
3. Siga as instruções e corrija erros se houver
4. Aguarde a validação completar

### 2.4 Distribuir para TestFlight

1. Ainda no Organizer, selecione o archive
2. Clique em **"Distribute App"**
3. Selecione **"App Store Connect"**
4. Clique em **"Next"**
5. Selecione **"Upload"**
6. Clique em **"Next"**
7. Marque **"Automatically manage signing"**
8. Clique em **"Next"**
9. Revise e clique em **"Upload"**
10. Aguarde o upload completar

## 📋 Passo 3: Configurar no App Store Connect

### 3.1 Criar App no App Store Connect

1. Acesse: https://appstoreconnect.apple.com
2. Faça login com sua conta Apple Developer
3. Clique em **"My Apps"**
4. Clique no botão **"+"** (criar novo app)
5. Preencha:
   - **Platform**: iOS
   - **Name**: Task2026 (ou o nome desejado)
   - **Primary Language**: Português (Brasil)
   - **Bundle ID**: Selecione o Bundle ID que você configurou
   - **SKU**: Um identificador único (ex: `task2026-001`)
6. Clique em **"Create"**

### 3.2 Configurar Informações do App

1. No App Store Connect, vá em **"App Information"**
2. Preencha:
   - **Category**: Selecione uma categoria apropriada
   - **Privacy Policy URL**: (opcional, mas recomendado)
3. Salve

### 3.3 Adicionar Build ao TestFlight

1. Vá na aba **"TestFlight"**
2. Aguarde o build aparecer (pode levar 10-30 minutos após o upload)
3. Quando aparecer, você verá o build na seção **"iOS Builds"**

## 👥 Passo 4: Adicionar Testadores

### 4.1 Testadores Internos (até 100)

1. No App Store Connect, vá em **"Users and Access"**
2. Adicione usuários como **"App Manager"** ou **"Developer"**
3. Esses usuários aparecerão automaticamente como testadores internos

### 4.2 Testadores Externos (até 10.000)

1. No App Store Connect, vá em **"TestFlight"**
2. Clique em **"External Testing"**
3. Clique em **"+"** para criar um grupo
4. Dê um nome ao grupo (ex: "Beta Testers")
5. Adicione o build que você fez upload
6. Preencha as informações de teste (obrigatório na primeira vez)
7. Adicione os emails dos testadores
8. Envie o convite

## 📲 Passo 5: Instalar no iPhone via TestFlight

### 5.1 Para Você (Desenvolvedor)

1. Instale o app **TestFlight** da App Store no seu iPhone
2. Abra o TestFlight
3. Faça login com sua Apple ID de desenvolvedor
4. O app aparecerá automaticamente
5. Toque em **"Install"** ou **"Update"**

### 5.2 Para Testadores Externos

1. Testadores receberão um email de convite
2. Devem instalar o app **TestFlight** da App Store
3. Abrir o link do convite no email
4. Aceitar o convite
5. O app aparecerá no TestFlight
6. Toque em **"Install"**

## 🔄 Passo 6: Atualizar o App

Quando fizer mudanças:

1. Atualize o **Build Number** no Xcode (incremente)
2. Crie um novo Archive (Product > Archive)
3. Faça upload para App Store Connect
4. Aguarde processamento
5. Adicione o novo build ao grupo de teste no TestFlight
6. Testadores receberão notificação de atualização

## ⚠️ Importante

- **Builds expiram em 90 dias** no TestFlight
- **Testadores externos**: Primeira versão precisa ser aprovada pela Apple (pode levar 24-48h)
- **Testadores internos**: Acesso imediato após upload
- **Limite**: Até 100 testadores internos, até 10.000 externos

## 🛠️ Comandos Úteis

```bash
# Limpar build
flutter clean

# Verificar configuração
flutter doctor -v

# Build para iOS (não necessário, Xcode faz isso)
flutter build ios --release
```

## 📚 Recursos

- **App Store Connect**: https://appstoreconnect.apple.com
- **Apple Developer**: https://developer.apple.com
- **Documentação TestFlight**: https://developer.apple.com/testflight/







