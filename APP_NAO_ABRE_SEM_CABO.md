# 📱 App Não Abre Sem Cabo - Solução

## ⚠️ Problema
O app não abre quando você desconecta o cabo USB.

## ✅ Soluções

### 1️⃣ Confiar no Desenvolvedor no iPhone

1. No iPhone, vá em **Configurações**
2. Vá em **Geral**
3. Role até encontrar **"VPN e Gerenciamento de Dispositivo"** (ou **"Device Management"** em inglês)
4. Toque nele
5. Você deve ver um perfil com seu nome ou email (ex: "JOSE PEREIRA DA SILVA FILHO" ou seu email)
6. Toque no perfil
7. Toque em **"Confiar em [seu nome]"** ou **"Trust [your name]"**
8. Confirme novamente quando solicitado

### 2️⃣ Reinstalar o App (Modo Release)

O app pode ter sido instalado em modo debug. Vamos instalar em modo release:

```bash
cd /Users/josepereiradasilvafilho/aplicativos/task/task2026

# Conecte o cabo USB novamente
flutter devices

# Instalar em modo release (mais estável)
flutter build ios --release

# Ou instalar diretamente
flutter install -d 00008110-0009598414E8401E
```

### 3️⃣ Verificar se o App Está Instalado

1. No iPhone, procure pelo app na tela inicial
2. O nome deve ser "Task2026" ou similar
3. Se não encontrar, pode ter sido desinstalado

### 4️⃣ Reinstalar Via Xcode

1. Conecte o cabo USB
2. Abra o Xcode: `open ios/Runner.xcworkspace`
3. Selecione seu iPhone no seletor (topo)
4. Pressione **Cmd + R** para executar
5. Aguarde instalar
6. Depois de instalar, configure para confiar (Passo 1)

### 5️⃣ Verificar Certificado

Se o app abrir mas fechar imediatamente:

1. No iPhone: **Configurações > Geral > VPN e Gerenciamento de Dispositivo**
2. Verifique se há um perfil de desenvolvedor
3. Se houver, toque e confie nele
4. Reinicie o iPhone se necessário

## 🔍 Diagnóstico

Execute para ver o status:
```bash
flutter devices
flutter install -d 00008110-0009598414E8401E
```

## 💡 Dica

Com certificado gratuito (Apple ID pessoal):
- O app pode expirar após 7 dias
- Quando expirar, precisa reinstalar
- Para evitar, pode assinar o Apple Developer Program (pago)







