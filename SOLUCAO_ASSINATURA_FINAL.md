# 🔐 Solução Definitiva: Assinatura no iPhone

## ⚠️ Problema Atual
- A conta `filhocefet1@gmail.com` está sendo rejeitada
- Não há perfil de provisionamento configurado

## ✅ Solução Passo a Passo

### 1️⃣ Abrir o Xcode
```bash
open ios/Runner.xcworkspace
```
**IMPORTANTE:** Use `.xcworkspace`, não `.xcodeproj`!

### 2️⃣ Configurar Conta Apple no Xcode

1. No Xcode, vá em **Xcode > Settings** (ou **Preferences**)
2. Clique na aba **"Accounts"**
3. Se a conta `filhocefet1@gmail.com` estiver lá:
   - Selecione-a
   - Clique em **"Remove"** (Remover) para remover
   - Clique no botão **"+"** (mais) no canto inferior esquerdo
   - Adicione sua **Apple ID** (mesma do iCloud)
   - Faça login com sua senha
4. Se não estiver, adicione sua Apple ID

### 3️⃣ Configurar Assinatura do Projeto

1. No Xcode, selecione o projeto **"Runner"** (ícone azul no topo)
2. Selecione o target **"Runner"** (não "RunnerTests")
3. Vá na aba **"Signing & Capabilities"**
4. **Desmarque** "Automatically manage signing" temporariamente
5. **Marque novamente** "Automatically manage signing"
6. No dropdown **"Team"**, selecione sua **Apple ID pessoal** (não a conta rejeitada)
7. Se aparecer um erro, clique em **"Try Again"**

### 4️⃣ Alterar Bundle Identifier (Opcional)

Se ainda não funcionar, altere o Bundle Identifier:

1. Ainda na aba "Signing & Capabilities"
2. Altere o **Bundle Identifier** de `com.example.task2026` para algo único:
   - Exemplo: `com.josepereira.task2026`
   - Ou: `com.seunome.task2026`
3. Clique em **"Try Again"**

### 5️⃣ Verificar Status

Você deve ver:
- ✅ Check verde indicando assinatura OK
- ✅ "Provisioning Profile" criado
- ✅ Nenhum erro em vermelho

### 6️⃣ Testar Build no Xcode

1. No Xcode, selecione seu iPhone no seletor de dispositivos (topo)
2. Pressione **Cmd + B** para fazer build
3. Se der erro, leia a mensagem e corrija
4. Se funcionar, o app está pronto!

## 🚀 Executar via Flutter

Depois de configurar no Xcode, execute:
```bash
cd /Users/josepereiradasilvafilho/aplicativos/task/task2026
flutter clean
flutter pub get
flutter run -d 00008110-0009598414E8401E
```

## 💡 Dicas Importantes

1. **Use sua Apple ID pessoal** (mesma do iCloud) - é gratuita
2. **Não precisa de conta Apple Developer paga** para testar no seu próprio iPhone
3. O certificado gratuito expira em 7 dias - depois precisa reinstalar
4. Se mudar o Bundle Identifier, precisa fazer isso no Xcode primeiro

## ⚠️ Se Ainda Não Funcionar

1. No Xcode, vá em **Product > Clean Build Folder** (Cmd + Shift + K)
2. Feche o Xcode completamente
3. Execute `flutter clean`
4. Abra o Xcode novamente e configure a assinatura
5. Tente fazer build no Xcode primeiro (Cmd + B)
6. Depois execute via Flutter







