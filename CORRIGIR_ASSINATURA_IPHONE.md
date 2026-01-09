# 🔐 Corrigir Assinatura para iPhone

## ⚠️ Problema
O Xcode não consegue assinar o app porque:
- A conta Apple Developer não está logada corretamente
- Não há perfil de provisionamento configurado

## ✅ Solução: Configurar Assinatura no Xcode

### Passo 1: Abrir o Projeto no Xcode
O Xcode já deve estar aberto. Se não estiver:
```bash
open ios/Runner.xcworkspace
```
**IMPORTANTE:** Use o `.xcworkspace`, NÃO o `.xcodeproj`!

### Passo 2: Configurar Assinatura Automática

1. No Xcode, selecione o projeto **"Runner"** no navegador esquerdo (ícone azul no topo)
2. Selecione o target **"Runner"** (não "RunnerTests")
3. Vá na aba **"Signing & Capabilities"** (Assinatura e Capacidades)
4. Marque a opção **"Automatically manage signing"** (Gerenciar assinatura automaticamente)
5. Selecione seu **Team** (Equipe):
   - Se você tem uma conta Apple Developer paga, selecione seu time
   - Se não tem, selecione sua **Apple ID pessoal** (sua conta iCloud)
   - O Xcode criará automaticamente um certificado de desenvolvedor gratuito

### Passo 3: Verificar Bundle Identifier

1. Ainda na aba "Signing & Capabilities"
2. Verifique o **Bundle Identifier**: deve ser algo como `com.example.task2026`
3. Se necessário, altere para algo único, como: `com.seunome.task2026`
   - Substitua "seunome" pelo seu nome ou algo único

### Passo 4: Resolver Erros (se houver)

Se aparecer algum erro:
- Clique em **"Try Again"** (Tentar Novamente)
- Ou clique em **"Add Account"** (Adicionar Conta) para adicionar sua Apple ID

### Passo 5: Verificar Status

Você deve ver:
- ✅ Um check verde indicando que a assinatura está OK
- ✅ "Provisioning Profile" criado automaticamente
- ✅ Nenhum erro em vermelho

## 🚀 Depois de Configurar

Feche o Xcode e execute novamente:
```bash
cd /Users/josepereiradasilvafilho/aplicativos/task/task2026
flutter run -d 00008110-0009598414E8401E
```

## 💡 Dica

Se você não tem uma conta Apple Developer paga:
- Use sua **Apple ID pessoal** (mesma do iCloud)
- O Xcode criará um certificado de desenvolvedor **gratuito**
- Você pode instalar apps no seu próprio iPhone sem custo
- Limitação: o app expira após 7 dias e precisa ser reinstalado

## ⚠️ Se Ainda Não Funcionar

1. No Xcode, vá em **Xcode > Settings** (ou **Preferences**)
2. Aba **"Accounts"**
3. Adicione sua Apple ID se não estiver lá
4. Selecione sua conta e clique em **"Download Manual Profiles"**
5. Volte para "Signing & Capabilities" e tente novamente







