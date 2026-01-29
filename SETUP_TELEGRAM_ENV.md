# 🚀 Setup Rápido - Variáveis de Ambiente Telegram

## Para Windows (PowerShell)

### 1️⃣ Executar Script de Configuração

Abra PowerShell **como Administrador** no diretório do projeto e execute:

```powershell
.\configurar_telegram_env.ps1
```

**O que o script faz:**
- ✅ Gera uma senha segura para `TELEGRAM_WEBHOOK_SECRET`
- ✅ Cria arquivos `.env` nas pastas das Edge Functions
- ✅ Salva todas as variáveis em `telegram_env_vars.txt` para referência
- ✅ Cria script `configurar_webhook.ps1` para configurar webhook

### 2️⃣ Verificar Arquivos Criados

Após executar, você terá:

```
supabase/functions/telegram-webhook/.env
supabase/functions/telegram-send/.env
telegram_env_vars.txt (para referência)
configurar_webhook.ps1 (para configurar webhook depois)
```

### 3️⃣ Deploy das Edge Functions

```powershell
# Login no Supabase (se ainda não fez)
supabase login

# Link com seu projeto self-hosted
supabase link --project-ref seu-projeto

# Deploy
supabase functions deploy telegram-webhook
supabase functions deploy telegram-send
```

### 4️⃣ Configurar Webhook

Depois do deploy, execute:

```powershell
.\configurar_webhook.ps1
```

Ou copie o comando curl do arquivo `telegram_env_vars.txt` e execute.

---

## Para Linux/Mac (Bash)

### 1️⃣ Executar Script de Configuração

```bash
bash configurar_telegram_env.sh
```

### 2️⃣ Deploy das Edge Functions

```bash
supabase login
supabase link --project-ref seu-projeto
supabase functions deploy telegram-webhook
supabase functions deploy telegram-send
```

### 3️⃣ Configurar Webhook

```bash
bash configurar_webhook.sh
```

---

## ⚠️ IMPORTANTE - Supabase Self-Hosted

Como você está usando **Supabase Self-Hosted**, as variáveis de ambiente funcionam através dos arquivos `.env` nas pastas das Edge Functions.

### Estrutura esperada:

```
supabase/
  functions/
    telegram-webhook/
      index.ts
      .env          ← Variáveis para esta função
    telegram-send/
      index.ts
      .env          ← Variáveis para esta função
```

### Conteúdo dos .env:

**telegram-webhook/.env:**
```env
TELEGRAM_BOT_TOKEN=8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec
TELEGRAM_WEBHOOK_SECRET=TgWh00k$ecr3t!2026TaskFlow#abc123
SUPABASE_URL=https://srv750497.hstgr.cloud
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key_aqui
```

**telegram-send/.env:**
```env
TELEGRAM_BOT_TOKEN=8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec
SUPABASE_URL=https://srv750497.hstgr.cloud
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key_aqui
```

---

## 🔐 Obter Service Role Key

A `SUPABASE_SERVICE_ROLE_KEY` você encontra em:

1. **Supabase Dashboard** → Settings → API
2. Ou no arquivo de configuração do seu Supabase self-hosted

**⚠️ Esta key é SECRETA! Não compartilhe e não faça commit dela no Git!**

---

## ✅ Verificar Configuração

Após tudo configurado, teste:

```bash
# Verificar webhook
curl "https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"
```

**Resposta esperada:**
```json
{
  "ok": true,
  "result": {
    "url": "https://srv750497.hstgr.cloud/functions/v1/telegram-webhook",
    "has_custom_certificate": false,
    "pending_update_count": 0
  }
}
```

---

## 🐛 Troubleshooting

### Erro: "Cannot find module"

As Edge Functions precisam das dependências. Certifique-se que os arquivos `index.ts` existem:
- `supabase/functions/telegram-webhook/index.ts`
- `supabase/functions/telegram-send/index.ts`

### Erro: "Unauthorized"

Verifique se o `SUPABASE_SERVICE_ROLE_KEY` está correto nos arquivos `.env`.

### Webhook não funciona

1. Verifique se o deploy foi bem-sucedido
2. Teste a URL manualmente:
   ```bash
   curl https://srv750497.hstgr.cloud/functions/v1/telegram-webhook
   ```
3. Veja os logs:
   ```bash
   supabase functions logs telegram-webhook
   ```

---

## 📚 Próximos Passos

Depois de configurar:
1. ✅ Executar migration SQL no banco
2. ✅ Testar vinculação de conta no app
3. ✅ Criar subscription de um chat
4. ✅ Testar envio de mensagens

Consulte: `INTEGRACAO_TELEGRAM.md` para guia completo.
