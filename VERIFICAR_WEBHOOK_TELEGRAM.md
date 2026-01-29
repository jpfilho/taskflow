# Verificar Webhook do Telegram (Telegram → Flutter)

## Problema
Mensagens enviadas do Telegram não estão chegando no chat do Flutter.

## Verificações no Servidor

### 1. Verificar se o webhook está configurado no Telegram

```bash
# Verificar webhook atual
curl "https://api.telegram.org/bot<SEU_TOKEN>/getWebhookInfo"

# Substitua <SEU_TOKEN> pelo token do bot
# Ou use variável de ambiente se estiver configurada
```

### 2. Verificar se Nginx faz proxy para /telegram-webhook

```bash
# Verificar se location /telegram-webhook existe
grep -A 10 "location /telegram-webhook" /etc/nginx/sites-enabled/supabase

# Se não existir, precisa adicionar (similar ao /send-message)
```

### 3. Verificar logs do Node.js

```bash
# Ver logs do serviço telegram-webhook
journalctl -u telegram-webhook -n 50 --no-pager

# Ver logs em tempo real
journalctl -u telegram-webhook -f
```

### 4. Testar webhook localmente

```bash
# Simular um update do Telegram
curl -X POST http://127.0.0.1:3001/telegram-webhook \
  -H 'Content-Type: application/json' \
  -H 'x-telegram-bot-api-secret-token: TgWebhook2026Taskflow_Secret' \
  -d '{
    "update_id": 123456,
    "message": {
      "message_id": 1,
      "from": {
        "id": 123456789,
        "first_name": "Teste",
        "username": "teste"
      },
      "chat": {
        "id": -1001234567890,
        "type": "supergroup"
      },
      "date": 1706299200,
      "message_thread_id": 123,
      "text": "Teste de mensagem"
    }
  }'
```

### 5. Verificar se mensagens estão sendo inseridas no Supabase

```bash
# Conectar ao PostgreSQL e verificar mensagens recentes
psql -h 127.0.0.1 -U postgres -d postgres -c "SELECT id, grupo_id, usuario_nome, conteudo, source, created_at FROM mensagens WHERE source = 'telegram' ORDER BY created_at DESC LIMIT 10;"
```

## Solução: Adicionar /telegram-webhook no Nginx

Se o `location /telegram-webhook` não existir no Nginx, adicione:

```bash
# Editar arquivo
nano /etc/nginx/sites-enabled/supabase
```

Adicione ANTES do `location /send-message`:

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

Depois:
```bash
nginx -t && systemctl reload nginx
```

## Verificar Webhook no Telegram

```bash
# Configurar webhook (substitua pelo seu token e URL)
curl -X POST "https://api.telegram.org/bot<SEU_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://api.taskflowv3.com.br/telegram-webhook",
    "secret_token": "TgWebhook2026Taskflow_Secret"
  }'
```

## Checklist de Diagnóstico

- [ ] Webhook configurado no Telegram apontando para `https://api.taskflowv3.com.br/telegram-webhook`
- [ ] Nginx tem `location /telegram-webhook` configurado
- [ ] Node.js está rodando e escutando na porta 3001
- [ ] Logs do Node.js mostram recebimento de updates
- [ ] Mensagens estão sendo inseridas no Supabase (source='telegram')
- [ ] Flutter está escutando mudanças via Realtime
