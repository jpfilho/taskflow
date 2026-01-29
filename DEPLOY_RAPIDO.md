# 🚀 DEPLOY RÁPIDO - GUIA DEFINITIVO

## ⭐ **MELHOR OPÇÃO (Igual no Mac)**

### **1. Via Git Bash (Recomendado) - Senha 1x apenas**

```powershell
.\deploy_via_bash.ps1
```

**Vantagens:**
- ✅ Pede senha **APENAS 1 VEZ**
- ✅ Usa `rsync` (muito mais rápido)
- ✅ Reutiliza conexão SSH
- ✅ Igual ao Mac (testado e confiável)

**Requisito:**
- Git for Windows instalado (https://git-scm.com/download/win)

---

### **2. Sem Build (usa build existente)**

```powershell
.\deploy_via_bash.ps1 -NoBuild
```

---

## 🔄 **COMPARAÇÃO:**

| Script | Senha | Tempo | Método |
|--------|-------|-------|--------|
| `deploy_via_bash.ps1` | **1x** | 2-3 min | rsync + SSH reuse ⭐ |
| `deploy_completo.ps1` | 4x | 5-8 min | scp múltiplo |
| `deploy_rapido.ps1` | 4x | 3-5 min | scp múltiplo |

---

## 📋 **PASSO A PASSO:**

### **Opção A: Com Build**

```powershell
.\deploy_via_bash.ps1
```

**O que faz:**
1. ✅ `flutter clean`
2. ✅ `flutter pub get`
3. ✅ `flutter build web --release`
4. ✅ Aplica cache-busting
5. ✅ Faz backup no servidor
6. ✅ Transfere via rsync (rápido!)
7. ✅ Ajusta permissões

⏱️ **Tempo:** 5-7 minutos
🔐 **Senha:** 1x apenas

---

### **Opção B: Sem Build (mais rápido)**

```powershell
.\deploy_via_bash.ps1 -NoBuild
```

⏱️ **Tempo:** 1-2 minutos
🔐 **Senha:** 1x apenas

---

## ❌ **SE GIT BASH NÃO ESTIVER INSTALADO:**

### **Instalar Git for Windows:**
1. Baixe: https://git-scm.com/download/win
2. Instale (deixe opções padrão)
3. Reinicie o PowerShell
4. Execute: `.\deploy_via_bash.ps1`

### **OU use o script PowerShell puro:**
```powershell
.\deploy_completo.ps1
```
(Vai pedir senha 4x, mas funciona)

---

## 🔑 **CONFIGURAR SSH PARA NÃO PEDIR SENHA:**

Execute UMA VEZ:

```powershell
# 1. Gerar chave
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa -N ""

# 2. Copiar para servidor (pede senha UMA VEZ)
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@212.85.0.249 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# 3. Testar (não deve pedir senha)
ssh root@212.85.0.249 "echo 'SSH OK!'"
```

Depois disso, **NUNCA MAIS** vai pedir senha! 🎉

---

## 🌐 **APÓS O DEPLOY:**

Acesse:
- http://212.85.0.249:8080/task2026/
- http://taskflowv3.com.br/

**Se não atualizar:**
- Pressione `Ctrl + Shift + R`
- Ou modo anônimo: `Ctrl + Shift + N`

---

## 📊 **RESUMO DOS SCRIPTS:**

| Arquivo | Descrição | Quando usar |
|---------|-----------|-------------|
| `deploy_via_bash.ps1` | ⭐ Usa bash (melhor) | **USE ESTE** |
| `deploy_completo.ps1` | PowerShell puro | Se não tiver Git Bash |
| `deploy_rapido.ps1` | PowerShell otimizado | Alternativa |
| `deploy_somente_transferir.ps1` | Só transfere | Debug |
| `deploy_agora.sh` | Bash original | Mac/Linux |

---

## ✅ **RECOMENDAÇÃO FINAL:**

```powershell
# 1. Instale Git for Windows (se não tiver)
# https://git-scm.com/download/win

# 2. Use o melhor script:
.\deploy_via_bash.ps1

# 3. Configure SSH (opcional, mas recomendado):
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa -N ""
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@212.85.0.249 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**Pronto! Deploy igual no Mac!** 🚀
