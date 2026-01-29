# Corrigir Webhook Telegram → Flutter

## Problema
Mensagens enviadas do Telegram não estão chegando no chat do Flutter. Os logs do Node.js não mostram "Update recebido".

## Solução Rápida (Execute no Servidor)

### 1. Verificar se location /telegram-webhook existe no Nginx

```bash
grep -A 10 "location /telegram-webhook" /etc/nginx/sites-enabled/supabase
```

**Se não retornar nada**, precisa adicionar.

### 2. Adicionar location /telegram-webhook no Nginx

```bash
# Editar arquivo
nano /etc/nginx/sites-enabled/supabase
```

**Adicione ANTES do `location /send-message`** (ou antes do `location /` final):

```nginx
    # Webhook do Telegram (recebe mensagens do Telegram)
    location /telegram-webhook {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header x-telegram-bot-api-secret-token $http_x_telegram_bot_api_secret_token;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
```

### 3. Testar e recarregar Nginx

```bash
nginx -t
systemctl reload nginx
```

### 4. Verificar webhook no Telegram

```bash
# Ver webhook atual (substitua pelo token do bot)
curl "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"
```

**Se o webhook não estiver configurado ou apontar para URL errada**, configure:

```bash
curl -X POST "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://api.taskflowv3.com.br/telegram-webhook",
    "secret_token": "TgWebhook2026Taskflow_Secret",
    "allowed_updates": ["message", "edited_message", "callback_query"],
    "drop_pending_updates": true
  }'
```

### 5. Monitorar logs em tempo real

```bash
journalctl -u telegram-webhook -f
```

**Envie uma mensagem no Telegram** e verifique se aparece:
- `📨 Update recebido:` nos logs

## Verificação Final

Execute estes comandos para verificar tudo:

```bash
# 1. Verificar Nginx
grep -A 5 "location /telegram-webhook" /etc/nginx/sites-enabled/supabase

# 2. Verificar webhook no Telegram
curl "https://api.telegram.org/bot8432168734:AAF_Rliq3plc5Crm2oAcLsgkfzqH5_Pywec/getWebhookInfo"

# 3. Verificar serviço Node.js
systemctl status telegram-webhook --no-pager | head -10

# 4. Ver logs recentes
journalctl -u telegram-webhook -n 20 --no-pager | grep -E "(Update recebido|telegram-webhook|ERRO)"
```

## Checklist

- [ ] Nginx tem `location /telegram-webhook` configurado
- [ ] Nginx foi recarregado (`systemctl reload nginx`)
- [ ] Webhook no Telegram aponta para `https://api.taskflowv3.com.br/telegram-webhook`
- [ ] Serviço `telegram-webhook` está ativo
- [ ] Logs mostram "Update recebido" quando envia mensagem no Telegram

## Scripts PowerShell (do Windows)

Se preferir usar scripts do Windows:

```powershell
# Adicionar location no Nginx
.\adicionar_telegram_webhook_nginx.ps1

# Configurar webhook no Telegram
.\configurar_webhook_nodejs.ps1

# Verificar tudo
.\verificar_webhook_completo.ps1
```
