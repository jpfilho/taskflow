# Como Conectar iPhone Físico via WiFi

## ⚠️ IMPORTANTE: Pré-requisitos
- iPhone e Mac devem estar na **mesma rede WiFi**
- iPhone deve estar **desbloqueado**
- Xcode instalado no Mac

## Passo 1: Conectar iPhone via Cabo USB
1. Conecte o iPhone ao Mac usando o cabo USB
2. Desbloqueie o iPhone e confie no computador (se solicitado)
3. Execute: `flutter devices` para verificar se o iPhone aparece

## Passo 2: Ativar Modo Desenvolvedor no iPhone
1. No iPhone, vá em **Configurações > Privacidade e Segurança**
2. Role até o final e toque em **Modo Desenvolvedor**
3. Ative o **Modo Desenvolvedor**
4. Reinicie o iPhone se solicitado
5. Após reiniciar, confirme novamente o Modo Desenvolvedor

## Passo 3: Configurar Conexão WiFi no Xcode
1. Abra o **Xcode**
2. Vá em **Window > Devices and Simulators** (ou pressione `Cmd + Shift + 2`)
3. Selecione seu iPhone na lista de dispositivos (deve aparecer conectado via USB)
4. Marque a opção **"Connect via network"** (Conectar via rede)
5. Aguarde até aparecer um ícone de WiFi 🌐 ao lado do dispositivo
6. O dispositivo deve mostrar "Connected" com ícone de WiFi

## Passo 4: Verificar Conexão
1. Desconecte o cabo USB do iPhone
2. O iPhone deve continuar aparecendo no Xcode com ícone de WiFi
3. Execute: `flutter devices --device-timeout 30` para verificar se o dispositivo aparece

## Passo 5: Executar a Aplicação
Execute o comando:
```bash
flutter run -d <device-id>
```

Ou simplesmente:
```bash
flutter run
```
(Se houver apenas um dispositivo iOS conectado)

## 🚀 Execução Rápida
Você também pode usar o script automatizado:
```bash
./executar_no_iphone.sh
```

## Troubleshooting

### Se o dispositivo não aparecer:
- Certifique-se de que o iPhone e o Mac estão na mesma rede WiFi
- Verifique se o Modo Desenvolvedor está ativado
- Tente reconectar via cabo e reativar "Connect via network"
- Reinicie o iPhone e o Mac se necessário
- Verifique se o firewall do Mac não está bloqueando a conexão

### Se aparecer erro de certificado:
- No iPhone, vá em **Configurações > Geral > VPN e Gerenciamento de Dispositivo**
- Toque no perfil do desenvolvedor e confie nele

### Se aparecer erro "code -27":
- O iPhone precisa estar no Modo Desenvolvedor
- Conecte via cabo primeiro para configurar a conexão WiFi
- Certifique-se de que ambos estão na mesma rede WiFi
