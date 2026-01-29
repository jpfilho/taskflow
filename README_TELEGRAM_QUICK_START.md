# 🚀 Quick Start - Integração Telegram

## ⚡ Setup Rápido (5 minutos)

### 1. Criar Bot
```bash
# Abrir @BotFather no Telegram
/newbot
# Guardar token: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
```

### 2. Executar Migration
```bash
# No diretório do projeto
supabase db push
```

### 3. Configurar Variáveis
No **Supabase Dashboard** → Edge Functions → Secrets:
```
TELEGRAM_BOT_TOKEN=seu_token_aqui
TELEGRAM_WEBHOOK_SECRET=senha_forte_secreta
```

### 4. Deploy Edge Functions
```bash
supabase login
supabase link --project-ref SEU_PROJECT_REF
supabase functions deploy telegram-webhook
supabase functions deploy telegram-send
```

### 5. Configurar Webhook
```bash
BOT_TOKEN="seu_token"
WEBHOOK_URL="https://SEU_PROJECT.supabase.co/functions/v1/telegram-webhook"
WEBHOOK_SECRET="sua_senha"

curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"${WEBHOOK_URL}\",\"secret_token\":\"${WEBHOOK_SECRET}\"}"
```

### 6. Verificar
```bash
curl "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"
```

---

## 📱 Uso no App

### Vincular Conta
1. Abrir qualquer chat no app
2. Clicar em ⚡ **Telegram** (AppBar)
3. Clicar em **"Vincular"**
4. Copiar link e abrir no Telegram
5. Enviar `/start` ao bot

### Ativar Espelhamento
1. No dialog Telegram, clicar em **"+"**
2. Escolher modo (grupo com tópicos recomendado)
3. Inserir **Chat ID** do grupo
4. (Opcional) Inserir **Topic ID**
5. Clicar em **"Ativar"**

### Obter Chat ID
1. Adicionar [@userinfobot](https://t.me/userinfobot) ao grupo
2. Bot enviará o Chat ID (ex: `-1001234567890`)

---

## ✅ Teste Rápido

### App → Telegram
1. Enviar "Olá Telegram!" no app
2. Verificar no grupo do Telegram

### Telegram → App
1. Enviar "Olá App!" no Telegram
2. Verificar no chat do app

---

## 📚 Documentação Completa

- **Setup detalhado:** `INTEGRACAO_TELEGRAM.md`
- **Checklist de testes:** `CHECKLIST_TESTES_TELEGRAM.md`

---

## 🐛 Troubleshooting Rápido

**Bot não responde?**
```bash
# Ver logs
supabase functions logs telegram-webhook --limit 20

# Verificar webhook
curl "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"
```

**Mensagens não chegam?**
```sql
-- Ver delivery logs
SELECT * FROM telegram_delivery_logs 
WHERE status = 'failed' 
ORDER BY created_at DESC;
```

**Erro "Chat not found"?**
- Verificar se bot está no grupo
- Verificar se bot é admin (grupos privados)
- Verificar Chat ID

---

## 🎯 Arquivos Criados

**Migrations:**
- `supabase/migrations/20260124_telegram_integration.sql`

**Edge Functions:**
- `supabase/functions/telegram-webhook/index.ts`
- `supabase/functions/telegram-send/index.ts`

**Flutter:**
- `lib/services/telegram_service.dart`
- `lib/widgets/telegram_config_dialog.dart`
- Alterações em `lib/services/chat_service.dart`
- Alterações em `lib/widgets/chat_screen.dart`

**Docs:**
- `INTEGRACAO_TELEGRAM.md` (completa)
- `CHECKLIST_TESTES_TELEGRAM.md`
- `README_TELEGRAM_QUICK_START.md` (este arquivo)

**Exemplos:**
- `telegram_bot_example.js` (bot de comandos Node.js)

---

## 💡 Dicas

- Use **grupo com tópicos** para melhor organização
- Um tópico por tarefa/chat
- Bot precisa ser **admin** em grupos privados
- Teste primeiro em grupo de teste
- Monitore os logs de delivery

---

## 🆘 Suporte

Problemas? Verifique:
1. Logs das Edge Functions
2. Webhook status no Telegram
3. Delivery logs no Supabase
4. Documentação completa

---

**Pronto!** 🎉 Sua integração está funcionando!
