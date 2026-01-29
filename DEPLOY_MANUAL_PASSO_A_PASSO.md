# 🚀 DEPLOY MANUAL - PASSO A PASSO

**Problema identificado:** O SSH está pedindo senha e travando os scripts automatizados.

**Solução:** Fazer o deploy manual em etapas.

---

## 📋 ETAPA 1: CONECTAR NO SERVIDOR

Abra um **novo terminal PowerShell** e conecte no servidor:

```powershell
ssh root@212.85.0.249
```

**Digite a senha quando solicitado.**

Deixe esta janela aberta durante todo o processo.

---

## 📋 ETAPA 2: PREPARAR DIRETÓRIOS NO SERVIDOR

**No terminal SSH (dentro do servidor)**, execute:

```bash
cd /root/supabase
mkdir -p volumes/functions/telegram-webhook
mkdir -p volumes/functions/telegram-send
ls -la volumes/functions/
```

Você deve ver os dois diretórios criados:
- `telegram-webhook/`
- `telegram-send/`

---

## 📋 ETAPA 3: COPIAR ARQUIVOS DO SEU PC PARA O SERVIDOR

**Abra OUTRO terminal PowerShell** (deixe o SSH aberto!) e execute:

```powershell
# Ir para o diretório do projeto
cd C:\aplicativos\taskflow\taskflow

# Copiar telegram-webhook
scp supabase\functions\telegram-webhook\index.ts root@212.85.0.249:/root/supabase/volumes/functions/telegram-webhook/
scp supabase\functions\telegram-webhook\.env root@212.85.0.249:/root/supabase/volumes/functions/telegram-webhook/

# Copiar telegram-send
scp supabase\functions\telegram-send\index.ts root@212.85.0.249:/root/supabase/volumes/functions/telegram-send/
scp supabase\functions\telegram-send\.env root@212.85.0.249:/root/supabase/volumes/functions/telegram-send/
```

**Você precisará digitar a senha para cada comando `scp`.**

---

## 📋 ETAPA 4: VERIFICAR ARQUIVOS NO SERVIDOR

**Volte para o terminal SSH (dentro do servidor)** e verifique:

```bash
ls -la /root/supabase/volumes/functions/telegram-webhook/
ls -la /root/supabase/volumes/functions/telegram-send/
```

**Deve aparecer:**
- `index.ts`
- `.env`

---

## 📋 ETAPA 5: REINICIAR CONTAINER

**No terminal SSH (dentro do servidor)**, execute:

```bash
cd /root/supabase
docker-compose restart edge-functions
```

Aguarde uns 5 segundos e depois:

```bash
docker-compose logs --tail=50 edge-functions
```

**Procure por:**
- ✅ `telegram-webhook` carregado
- ✅ `telegram-send` carregado
- ❌ Se aparecer erros, copie e me mostre

---

## 📋 ETAPA 6: TESTAR ENDPOINTS

**Ainda no servidor SSH**, teste:

```bash
curl -k https://212.85.0.249/functions/v1/telegram-webhook
curl -k https://212.85.0.249/functions/v1/telegram-send
```

**Resposta esperada:**
- Pode ser erro `405 Method Not Allowed` ou `401 Unauthorized` → **NORMAL! Significa que está funcionando!**
- ❌ Se aparecer erro de conexão ou 404 → algo errado

---

## 🎉 PRONTO!

Se tudo funcionou, agora você pode:

1. ✅ **Configurar webhook do Telegram:**
   ```powershell
   .\configurar_webhook.ps1
   ```

2. ✅ **Executar migration SQL** (via Supabase Studio)

3. ✅ **Testar no Flutter**

---

## 💡 DICA: Configurar Chave SSH (opcional, para futuro)

Para evitar digitar senha toda hora:

```powershell
# Gerar chave SSH (se não tiver)
ssh-keygen -t rsa -b 4096

# Copiar chave para servidor
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@212.85.0.249 "cat >> ~/.ssh/authorized_keys"
```

Depois disso, não precisará mais de senha!

---

## ❓ PROBLEMAS?

Se algo der errado em alguma etapa, **me avise e copie a mensagem de erro!**
