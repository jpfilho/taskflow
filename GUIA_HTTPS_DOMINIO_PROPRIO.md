# 🌐 Guia: HTTPS com Domínio Próprio (taskflow3.com.br)

## 🎯 Objetivo

Configurar `api.taskflow3.com.br` com HTTPS para o Supabase, permitindo webhooks do Telegram.

**Resultado esperado:**
- ✅ `https://api.taskflow3.com.br` → Supabase
- ✅ Certificado SSL válido (Let's Encrypt)
- ✅ Telegram webhook funcionando

---

## 📋 PASSO 1: Configurar DNS (Hostinger)

### 1.1 Acessar Painel DNS

1. Login em: https://hpanel.hostinger.com
2. Vá em **Domínios** → `taskflow3.com.br`
3. Clique em **DNS / Nameservers**

### 1.2 Adicionar Registro A

Clique em **"Adicionar registro"** e preencha:

```
Tipo: A
Nome: api
Aponta para: 212.85.0.249
TTL: 3600 (ou deixe padrão)
```

**Resultado:** `api.taskflow3.com.br` → `212.85.0.249`

### 1.3 Aguardar Propagação

⏱️ **Aguarde 5-15 minutos** para o DNS propagar.

**Testar propagação:**
```bash
# No seu PC Windows
nslookup api.taskflow3.com.br

# Ou
ping api.taskflow3.com.br
```

**Resposta esperada:** `212.85.0.249`

---

## 📋 PASSO 2: Configurar HTTPS no Servidor

### 2.1 Conectar via SSH

**Opção A: Via Hostinger (navegador)**
1. No hpanel, vá em **VPS**
2. Clique em **Terminal SSH**

**Opção B: Via SSH local**
```bash
ssh root@212.85.0.249
```

### 2.2 Baixar Script de Configuração

```bash
# No servidor
cd /root
wget https://raw.githubusercontent.com/seu-repo/configurar_https_taskflow.sh
chmod +x configurar_https_taskflow.sh
```

**OU copiar manualmente:**

1. No seu PC, abra: `configurar_https_taskflow.sh`
2. Copie todo o conteúdo
3. No servidor SSH:
```bash
nano configurar_https_taskflow.sh
# Cole o conteúdo (Ctrl+Shift+V)
# Salve (Ctrl+X, Y, Enter)
chmod +x configurar_https_taskflow.sh
```

### 2.3 Editar Email no Script

```bash
nano configurar_https_taskflow.sh
```

**Encontre a linha ~10:**
```bash
EMAIL="seu-email@example.com"  # ⚠️ ALTERE PARA SEU EMAIL
```

**Altere para:**
```bash
EMAIL="seuemail@taskflow3.com.br"  # Seu email real
```

Salve: `Ctrl+X`, `Y`, `Enter`

### 2.4 Executar Script

```bash
bash configurar_https_taskflow.sh
```

**O script vai:**
1. ✅ Atualizar sistema
2. ✅ Instalar Nginx e Certbot
3. ✅ Gerar certificado SSL
4. ✅ Configurar proxy reverso
5. ✅ Configurar renovação automática

**Tempo estimado:** 5-10 minutos

### 2.5 Possíveis Erros

#### ❌ Erro: "DNS not propagated"

**Solução:** Aguarde mais 10 minutos e tente novamente.

```bash
# Verificar DNS no servidor
nslookup api.taskflow3.com.br
```

#### ❌ Erro: "Port 80 already in use"

**Solução:** Parar serviço que usa porta 80:

```bash
# Ver o que está usando porta 80
lsof -i :80

# Se for apache2
systemctl stop apache2
systemctl disable apache2

# Executar script novamente
bash configurar_https_taskflow.sh
```

#### ❌ Erro: "Certificate validation failed"

**Solução:** Verificar se porta 80 está acessível externamente:

```bash
# No seu PC
curl http://api.taskflow3.com.br
```

---

## 📋 PASSO 3: Testar HTTPS

### 3.1 Testar no Navegador

Abra: **https://api.taskflow3.com.br**

**Resposta esperada:**
- 🔒 Cadeado verde (SSL válido)
- Erro 401 Unauthorized (normal, é autenticação)

### 3.2 Testar via Curl

```bash
# No seu PC
curl https://api.taskflow3.com.br
```

**Resposta esperada:**
```json
{"message":"Unauthorized"}
```

### 3.3 Testar Edge Functions

```bash
curl https://api.taskflow3.com.br/functions/v1/telegram-webhook
```

**Se retornar 404:** Functions ainda não deployadas (normal).  
**Se retornar 401:** Perfeito! Endpoint existe.

---

## 📋 PASSO 4: Atualizar Flutter

### 4.1 Editar supabase_config.dart

Abra: `lib/config/supabase_config.dart`

**Altere:**
```dart
// ANTES
static const String supabaseUrl = 'http://212.85.0.249:8000/';

// DEPOIS
static const String supabaseUrl = 'https://api.taskflow3.com.br';
```

### 4.2 Testar App

1. Salve o arquivo
2. Reinicie o app (Hot Restart)
3. Faça login novamente
4. Teste alguma funcionalidade

**Se der erro SSL:** Limpe cache do app ou reinstale.

---

## 📋 PASSO 5: Deploy Edge Functions

### 5.1 Atualizar Scripts

**Editar:** `deploy_telegram_functions.ps1` (linha ~8)

```powershell
# ANTES
$SSHHost = "srv750497.hstgr.cloud"

# DEPOIS  
$SSHHost = "212.85.0.249"  # Ou deixe como está, ambos funcionam
```

**Editar:** `configurar_telegram_env.ps1` (linha ~5)

```powershell
# ANTES
$SUPABASE_URL = "https://srv750497.hstgr.cloud"

# DEPOIS
$SUPABASE_URL = "https://api.taskflow3.com.br"
```

### 5.2 Reconfigurar Env Vars

```powershell
# No seu PC
.\configurar_telegram_env.ps1
```

### 5.3 Deploy

```powershell
.\deploy_telegram_functions.ps1
```

---

## 📋 PASSO 6: Configurar Webhook Telegram

### 6.1 Editar configurar_webhook.ps1

Abra `configurar_webhook.ps1` e verifique se está usando a URL correta.

Ou execute manualmente:

```powershell
$TELEGRAM_BOT_TOKEN = "8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec"
$WEBHOOK_SECRET = "SEU_WEBHOOK_SECRET"  # Do telegram_env_vars.txt

$body = @{
    url = "https://api.taskflow3.com.br/functions/v1/telegram-webhook"
    secret_token = $WEBHOOK_SECRET
    allowed_updates = @("message", "edited_message", "callback_query")
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body
```

### 6.2 Verificar Webhook

```powershell
curl "https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"
```

**Resposta esperada:**
```json
{
  "ok": true,
  "result": {
    "url": "https://api.taskflow3.com.br/functions/v1/telegram-webhook",
    "has_custom_certificate": false,
    "pending_update_count": 0
  }
}
```

---

## ✅ CHECKLIST FINAL

- [ ] DNS configurado (api.taskflow3.com.br → 212.85.0.249)
- [ ] DNS propagado (teste com nslookup/ping)
- [ ] Script HTTPS executado no servidor
- [ ] Certificado SSL gerado
- [ ] Nginx configurado e rodando
- [ ] HTTPS testado e funcionando
- [ ] Flutter atualizado com nova URL
- [ ] Edge Functions deployadas
- [ ] Webhook Telegram configurado
- [ ] Webhook verificado e ativo
- [ ] Teste end-to-end: Mensagem App → Telegram
- [ ] Teste end-to-end: Mensagem Telegram → App

---

## 🎉 Parabéns!

Se todos os itens acima estão ✅, sua integração Telegram está **100% funcional!**

---

## 🆘 Problemas Comuns

### SSL não funciona

```bash
# No servidor
systemctl status nginx
systemctl status certbot.timer

# Ver logs
tail -f /var/log/nginx/supabase_error.log
```

### Webhook não recebe mensagens

```bash
# No servidor
docker-compose logs -f edge-functions | grep telegram
```

### App não conecta

1. Limpar cache do app
2. Fazer logout/login
3. Reinstalar app
4. Verificar se URL está correta em `supabase_config.dart`

---

## 📚 Documentação de Referência

- `SOLUCAO_HTTPS_TELEGRAM.md` - Outras soluções HTTPS
- `INTEGRACAO_TELEGRAM.md` - Documentação completa
- `CHECKLIST_TESTES_TELEGRAM.md` - Testes detalhados
