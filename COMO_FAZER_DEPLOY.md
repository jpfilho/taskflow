# 🚀 COMO FAZER DEPLOY DA APLICAÇÃO WEB

## 📋 **PRÉ-REQUISITOS:**

### **No Windows:**
1. ✅ Flutter instalado
2. ✅ OpenSSH Client instalado (já vem no Windows 10/11)
3. ✅ Acesso SSH ao servidor (212.85.0.249)

### **Verificar se tem SSH:**
```powershell
ssh -V
```

Se não tiver, instale:
- Windows 10/11: Configurações > Apps > Recursos Opcionais > OpenSSH Client

---

## 🚀 **OPÇÃO 1: DEPLOY COMPLETO (COM BUILD)**

### **PowerShell (Windows):**

```powershell
.\deploy_agora.ps1
```

**O que faz:**
1. ✅ `flutter clean` - Limpa build anterior
2. ✅ `flutter pub get` - Baixa dependências
3. ✅ `flutter build web --release` - Compila para web
4. ✅ Aplica cache-busting (versão com timestamp)
5. ✅ Desabilita service worker (evita cache problemático)
6. ✅ Cria backup no servidor
7. ✅ Transfere arquivos via SCP
8. ✅ Ajusta permissões (www-data)
9. ✅ Verifica se deploy foi bem-sucedido

⏱️ **Tempo:** 5-10 minutos

---

## ⚡ **OPÇÃO 2: DEPLOY RÁPIDO (SEM BUILD)**

Se você **já fez o build** e só quer atualizar os arquivos no servidor:

```powershell
.\deploy_agora.ps1 -NoBuild
```

**O que faz:**
- ✅ Pula `flutter build web`
- ✅ Usa o build existente em `build/web/`
- ✅ Transfere arquivos para o servidor

⏱️ **Tempo:** 1-2 minutos

---

## 🐧 **BASH (Linux/Mac/Git Bash):**

```bash
./deploy_agora.sh
```

Ou sem build:
```bash
./deploy_agora.sh --no-build
```

---

## 🔐 **AUTENTICAÇÃO SSH:**

### **Primeira vez:**
Você precisará digitar a senha do servidor **múltiplas vezes**:
- 1x para criar diretório
- 1x para fazer backup
- 1x para limpar destino
- 1x para transferir arquivos
- 1x para ajustar permissões

### **Para evitar digitar senha toda hora:**

#### **Opção A: Usar chave SSH (Recomendado)**

1. Gerar chave (se não tiver):
```powershell
ssh-keygen -t rsa -b 4096
```

2. Copiar para servidor:
```powershell
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@212.85.0.249 "cat >> ~/.ssh/authorized_keys"
```

3. Testar:
```powershell
ssh root@212.85.0.249
```
(Não deve pedir senha)

#### **Opção B: Usar agente SSH**

```powershell
# Iniciar agente SSH
Start-Service ssh-agent

# Adicionar chave
ssh-add $env:USERPROFILE\.ssh\id_rsa
```

---

## 🌐 **ACESSAR A APLICAÇÃO:**

Após o deploy, acesse:

- **URL Direta:** http://212.85.0.249:8080/task2026/
- **Domínio:** http://taskflowv3.com.br/ (redireciona)

---

## 🔄 **SE O NAVEGADOR NÃO ATUALIZAR:**

### **Forçar atualização:**
1. **Chrome/Edge:** `Ctrl + Shift + R`
2. **Firefox:** `Ctrl + Shift + R`
3. **Safari:** `Cmd + Option + R`

### **Limpar cache:**
1. Abra DevTools: `F12`
2. Clique com botão direito no ícone de atualizar
3. Selecione "Limpar cache e atualizar"

### **Modo anônimo:**
- `Ctrl + Shift + N` (Chrome/Edge)
- `Ctrl + Shift + P` (Firefox)

---

## ❌ **SOLUÇÃO DE PROBLEMAS:**

### **Erro: "flutter: command not found"**
```powershell
# Adicionar Flutter ao PATH
$env:PATH += ";C:\flutter\bin"
```

### **Erro: "ssh: command not found"**
- Instale OpenSSH Client (veja Pré-requisitos)

### **Erro: "Permission denied (publickey,password)"**
- Senha incorreta
- Ou usuário não tem permissão SSH

### **Erro: "build/web not found"**
```powershell
# Fazer build manualmente
flutter build web --release --base-href="/task2026/"
```

### **Arquivos não atualizaram no servidor:**
```powershell
# Verificar versão no servidor
ssh root@212.85.0.249 "cat /var/www/html/task2026/version.txt"

# Limpar tudo e refazer deploy
ssh root@212.85.0.249 "rm -rf /var/www/html/task2026/*"
.\deploy_agora.ps1
```

---

## 📁 **ESTRUTURA DE ARQUIVOS:**

```
project/
├── build/
│   └── web/              ← Arquivos compilados
│       ├── index.html
│       ├── main.dart.js
│       ├── flutter.js
│       ├── version.txt   ← Timestamp do build
│       └── ...
├── deploy_agora.ps1      ← Script PowerShell (Windows)
├── deploy_agora.sh       ← Script Bash (Linux/Mac)
└── COMO_FAZER_DEPLOY.md  ← Este arquivo
```

---

## 🔧 **PERSONALIZAR O DEPLOY:**

### **Mudar servidor:**
Edite o script:
```powershell
$SERVER = "seu-usuario@seu-servidor.com"
$REMOTE_PATH = "/caminho/no/servidor"
```

### **Mudar base-href:**
Edite o comando build:
```powershell
flutter build web --release --base-href="/seu-caminho/"
```

---

## 📊 **VERIFICAR LOGS NO SERVIDOR:**

```powershell
# Logs do Nginx
ssh root@212.85.0.249 "tail -f /var/log/nginx/access.log"

# Verificar permissões
ssh root@212.85.0.249 "ls -la /var/www/html/task2026/"

# Verificar se arquivos existem
ssh root@212.85.0.249 "ls -lh /var/www/html/task2026/"
```

---

## ✅ **CHECKLIST PÓS-DEPLOY:**

- [ ] Navegador abre http://212.85.0.249:8080/task2026/
- [ ] Login funciona
- [ ] Navegação entre telas funciona
- [ ] Dados carregam corretamente
- [ ] Versão no rodapé está atualizada
- [ ] Ctrl+Shift+R atualiza para nova versão

---

## 💡 **DICAS:**

1. **Sempre teste localmente primeiro:**
   ```powershell
   flutter run -d chrome
   ```

2. **Faça backup antes de deploy grande:**
   - O script já faz backup automaticamente

3. **Use Git para controle de versão:**
   ```powershell
   git add .
   git commit -m "Deploy versao X"
   git push
   ```

4. **Monitore o tamanho do build:**
   - Build muito grande (>50MB) = lento para baixar
   - Otimize imagens e assets

---

**Qualquer dúvida, consulte este arquivo!** 📚
