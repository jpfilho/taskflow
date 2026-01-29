# ⚡ Guia Rápido - Deploy Telegram (Hostinger VPS Docker)

## 🎯 Resumo

Você está em: **Hostinger VPS com Supabase via Docker**  
Servidor: `srv750497.hstgr.cloud`

---

## 🚀 Deploy em 3 Passos

### 1️⃣ Configurar Variáveis de Ambiente ✅

**Antes de executar**, edite `configurar_telegram_env.ps1`:
- Linha ~13: Adicione sua `SUPABASE_SERVICE_ROLE_KEY`

```powershell
# Windows (PowerShell como Admin)
.\configurar_telegram_env.ps1
```

**Resultado:**
- ✅ Arquivos `.env` criados em `supabase/functions/*/`
- ✅ `telegram_env_vars.txt` com as variáveis

---

### 2️⃣ Deploy das Edge Functions

**Opção A: Script Automatizado (Recomendado)**

```powershell
# Windows
.\deploy_telegram_functions.ps1
```

```bash
# Linux/Mac
chmod +x deploy_telegram_functions.sh
bash deploy_telegram_functions.sh
```

**O que o script faz:**
1. Verifica arquivos locais
2. Cria diretórios no servidor via SSH
3. Copia arquivos via SCP
4. Ajusta permissões
5. Reinicia container `edge-functions`
6. Testa endpoint

---

**Opção B: Manual via SSH**

```bash
# 1. Conectar SSH
ssh root@srv750497.hstgr.cloud

# 2. Criar diretórios
mkdir -p /opt/supabase/volumes/functions/{telegram-webhook,telegram-send}

# 3. Sair do SSH (Ctrl+D) e copiar arquivos
scp -r supabase/functions/telegram-webhook root@srv750497.hstgr.cloud:/opt/supabase/volumes/functions/
scp -r supabase/functions/telegram-send root@srv750497.hstgr.cloud:/opt/supabase/volumes/functions/

# 4. Voltar ao SSH e reiniciar
ssh root@srv750497.hstgr.cloud
cd /opt/supabase
docker-compose restart edge-functions
docker-compose logs -f edge-functions
```

---

### 3️⃣ Configurar Webhook do Telegram

```powershell
# Windows
.\configurar_webhook.ps1
```

```bash
# Linux/Mac
bash configurar_webhook.sh
```

**Verificar:**

```bash
curl "https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"
```

**Resposta esperada:**
```json
{
  "ok": true,
  "result": {
    "url": "https://srv750497.hstgr.cloud/functions/v1/telegram-webhook",
    "pending_update_count": 0
  }
}
```

---

## 🗄️ Executar Migration SQL

No **Supabase Studio** ou via `psql`:

```sql
-- Copiar e colar o conteúdo de:
-- supabase/migrations/20260124_telegram_integration.sql
```

Ou via painel Hostinger:
1. Acesse o container `supabase-db`
2. Abra SQL Editor
3. Cole o SQL da migration
4. Execute

---

## ✅ Testar Integração

### 1. Teste Básico - Bot Responde

No Telegram, envie para `@TaskFlow_chat_bot`:
```
/start
```

**Esperado:** Bot responde com mensagem de boas-vindas.

---

### 2. Teste de Vinculação

**No App Flutter:**
1. Abra qualquer chat
2. Clique no ícone ⚡ Telegram (AppBar)
3. Clique em "Vincular Telegram"
4. Copie o link gerado
5. Cole no Telegram

**Esperado:** Bot confirma vinculação.

---

### 3. Teste de Envio App → Telegram

1. No app, ative "Espelhamento Telegram" para um chat
2. Configure o destino (DM ou grupo)
3. Envie uma mensagem no chat do app

**Esperado:** Mensagem aparece no Telegram.

---

### 4. Teste de Recebimento Telegram → App

1. No Telegram, envie uma mensagem no chat configurado
2. Abra o app Flutter no mesmo chat

**Esperado:** Mensagem aparece no app.

---

## 🔧 Troubleshooting Rápido

### Webhook não configurado

```bash
# Ver status
curl "https://api.telegram.org/bot8432168734:AAF_R1iq3p1c5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"

# Reconfigurar
.\configurar_webhook.ps1
```

### Edge Function não responde

```bash
# SSH no servidor
ssh root@srv750497.hstgr.cloud

# Ver logs
cd /opt/supabase
docker-compose logs -f edge-functions

# Reiniciar
docker-compose restart edge-functions
```

### Mensagens não chegam no Telegram

```bash
# Ver logs da função telegram-send
ssh root@srv750497.hstgr.cloud
cd /opt/supabase
docker-compose logs -f edge-functions | grep telegram-send
```

### Mensagens do Telegram não chegam no app

```bash
# Ver logs da função telegram-webhook
ssh root@srv750497.hstgr.cloud
cd /opt/supabase
docker-compose logs -f edge-functions | grep telegram-webhook
```

---

## 📁 Arquivos Importantes

```
C:\aplicativos\taskflow\taskflow\
├── configurar_telegram_env.ps1        ← Configurar env vars
├── deploy_telegram_functions.ps1      ← Deploy automatizado
├── configurar_webhook.ps1             ← Configurar webhook
├── telegram_env_vars.txt              ← Variáveis de referência
├── DEPLOY_EDGE_FUNCTIONS_DOCKER.md    ← Guia completo
├── INTEGRACAO_TELEGRAM.md             ← Documentação técnica
└── supabase/
    ├── migrations/
    │   └── 20260124_telegram_integration.sql
    └── functions/
        ├── telegram-webhook/
        │   ├── index.ts
        │   └── .env
        └── telegram-send/
            ├── index.ts
            └── .env
```

---

## 📞 Suporte

Consulte a documentação completa:
- `INTEGRACAO_TELEGRAM.md` - Documentação técnica
- `DEPLOY_EDGE_FUNCTIONS_DOCKER.md` - Deploy detalhado
- `CHECKLIST_TESTES_TELEGRAM.md` - Testes completos

---

## 🎯 Checklist Final

- [ ] Variáveis de ambiente configuradas
- [ ] Edge Functions deployadas
- [ ] Webhook configurado
- [ ] Migration SQL executada
- [ ] Bot responde no Telegram
- [ ] Vinculação funciona
- [ ] Mensagens App → Telegram OK
- [ ] Mensagens Telegram → App OK

**Tudo OK? Parabéns! 🎉 Integração Telegram concluída!**
