# 📱 Guia Completo: Executar App no iPhone

## ✅ Pré-requisitos Verificados
- ✅ Flutter instalado e configurado
- ✅ Xcode instalado (versão 16.4)
- ✅ CocoaPods instalado e dependências atualizadas
- ✅ Projeto limpo e dependências instaladas

## 🔧 Passo 1: Conectar iPhone ao Mac

### Opção A: Via Cabo USB (Recomendado para primeira vez)
1. Conecte o iPhone ao Mac usando cabo USB
2. Desbloqueie o iPhone
3. Se aparecer "Confiar neste computador?", toque em **Confiar**
4. Aguarde alguns segundos para o Mac reconhecer o dispositivo

### Opção B: Via WiFi (Após configurar uma vez)
1. Primeiro, conecte via cabo USB e siga os passos abaixo
2. Depois você poderá desconectar e usar WiFi

## 🔓 Passo 2: Ativar Modo Desenvolvedor no iPhone

1. No iPhone, abra **Configurações**
2. Vá em **Privacidade e Segurança**
3. Role até o final e toque em **Modo Desenvolvedor**
4. Ative o **Modo Desenvolvedor**
5. Se solicitado, reinicie o iPhone
6. Após reiniciar, confirme novamente o Modo Desenvolvedor

## 📲 Passo 3: Configurar no Xcode (Primeira vez)

1. Abra o **Xcode** no Mac
2. Vá em **Window > Devices and Simulators** (ou pressione `Cmd + Shift + 2`)
3. Selecione seu iPhone na lista (deve aparecer conectado)
4. Se for a primeira vez:
   - Clique em **"Use for Development"** (Usar para Desenvolvimento)
   - Aguarde o Xcode preparar o dispositivo
5. Para usar WiFi (opcional):
   - Marque a opção **"Connect via network"** (Conectar via rede)
   - Aguarde até aparecer um ícone de WiFi 🌐 ao lado do dispositivo

## 🚀 Passo 4: Executar o App

### Método 1: Usando Flutter CLI (Recomendado)

Abra o terminal e execute:

```bash
cd /Users/josepereiradasilvafilho/aplicativos/task/task2026

# Verificar dispositivos conectados
flutter devices

# Executar no iPhone (substitua <device-id> pelo ID do seu iPhone)
flutter run -d <device-id>

# OU, se houver apenas um dispositivo iOS:
flutter run
```

### Método 2: Usando o Script Automatizado

```bash
cd /Users/josepereiradasilvafilho/aplicativos/task/task2026
chmod +x executar_no_iphone.sh
./executar_no_iphone.sh
```

### Método 3: Usando Xcode

1. Abra o Xcode
2. Abra o workspace: `ios/Runner.xcworkspace` (NÃO o .xcodeproj)
3. Selecione seu iPhone no seletor de dispositivos (topo da janela)
4. Clique no botão **Play** ▶️ ou pressione `Cmd + R`

## 🔍 Verificar Dispositivos Conectados

Execute no terminal:
```bash
flutter devices --device-timeout 30
```

Você deve ver algo como:
```
iPhone de JOSE • 00008030-001A... • ios • com.apple.dt.Xcode... • iOS 18.x
```

## ⚠️ Troubleshooting

### Problema: "No devices found"
**Solução:**
- Certifique-se de que o iPhone está desbloqueado
- Verifique se o cabo USB está funcionando
- Tente reconectar o cabo
- Verifique se o Modo Desenvolvedor está ativado

### Problema: "code -27" ou "Developer Mode"
**Solução:**
- Ative o Modo Desenvolvedor no iPhone (Passo 2)
- Reinicie o iPhone após ativar
- Conecte via cabo USB primeiro

### Problema: "Untrusted Developer"
**Solução:**
1. No iPhone, vá em **Configurações > Geral > VPN e Gerenciamento de Dispositivo**
2. Toque no perfil do desenvolvedor (seu nome ou email)
3. Toque em **Confiar em [seu nome]**
4. Confirme novamente

### Problema: "Signing requires a development team"
**Solução:**
1. Abra `ios/Runner.xcworkspace` no Xcode
2. Selecione o projeto "Runner" no navegador
3. Vá na aba "Signing & Capabilities"
4. Marque "Automatically manage signing"
5. Selecione seu Team (Apple ID)

### Problema: App não instala ou fecha imediatamente
**Solução:**
- Verifique se o certificado de desenvolvedor está válido
- Tente limpar o build: `flutter clean && flutter pub get`
- Reinstale os pods: `cd ios && pod install`

## 📝 Comandos Úteis

```bash
# Limpar build
flutter clean

# Instalar dependências
flutter pub get

# Verificar dispositivos
flutter devices

# Executar em modo release (mais rápido, sem hot reload)
flutter run --release

# Executar com logs detalhados
flutter run -v

# Verificar configuração do Flutter
flutter doctor -v
```

## 🎯 Próximos Passos

Após executar com sucesso:
1. O app será instalado no iPhone
2. Você poderá usar **Hot Reload** (salvar arquivos e ver mudanças instantaneamente)
3. Para parar, pressione `q` no terminal ou `Cmd + C`

## 💡 Dica

Se você configurou a conexão WiFi no Xcode, pode desconectar o cabo USB e o iPhone continuará aparecendo como dispositivo disponível para desenvolvimento!







