# 🚀 Executar no iPhone - Guia Rápido

## ⚡ Passos Rápidos

### 1️⃣ Conecte o iPhone via USB
- Conecte o cabo USB ao Mac
- Desbloqueie o iPhone
- Confie no computador (se solicitado)

### 2️⃣ Ative o Modo Desenvolvedor no iPhone
- **Configurações** > **Privacidade e Segurança** > **Modo Desenvolvedor** > **Ativar**
- Reinicie o iPhone se solicitado

### 3️⃣ Configure no Xcode (primeira vez)
```bash
# Abra o Xcode e vá em:
Window > Devices and Simulators (Cmd + Shift + 2)
```
- Selecione seu iPhone
- Clique em **"Use for Development"**

### 4️⃣ Execute o App
```bash
cd /Users/josepereiradasilvafilho/aplicativos/task/task2026

# Verificar se o iPhone aparece
flutter devices

# Executar (substitua pelo ID do seu iPhone)
flutter run -d <device-id>
```

## 🔧 Se o iPhone não aparecer:

1. **Verifique o cabo USB** - tente outro cabo ou porta USB
2. **Desbloqueie o iPhone** - mantenha desbloqueado
3. **Ative o Modo Desenvolvedor** - Configurações > Privacidade e Segurança > Modo Desenvolvedor
4. **Reinicie o iPhone** após ativar o Modo Desenvolvedor
5. **Confie no computador** - quando conectar, toque em "Confiar"

## 📱 Depois de configurado:

Você pode usar WiFi! No Xcode:
- Window > Devices and Simulators
- Selecione seu iPhone
- Marque **"Connect via network"**
- Depois pode desconectar o cabo USB

## ⚠️ Erro "Untrusted Developer"?

No iPhone:
- **Configurações** > **Geral** > **VPN e Gerenciamento de Dispositivo**
- Toque no seu perfil de desenvolvedor
- Toque em **"Confiar"**

---

**Pronto!** O app será instalado e executado no seu iPhone! 🎉







