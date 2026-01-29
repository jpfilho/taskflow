# Corrigir Exclusão Bidirecional (Flutter ↔ Telegram)

## Problemas Identificados

1. **Flutter → Telegram**: Endpoint `/delete-message` não está configurado no Nginx
2. **Telegram → Flutter**: Bot API não recebe updates de mensagens deletadas manualmente

## Solução 1: Adicionar /delete-message no Nginx

### No Servidor

```bash
# 1. Verificar se location /delete-message existe
grep -A 10 "location /delete-message" /etc/nginx/sites-enabled/supabase

# 2. Se não existir, adicionar
nano /etc/nginx/sites-enabled/supabase
```

**Adicione ANTES do `location /send-message`:**

```nginx
    # Endpoint para deletar mensagens (Flutter → Telegram)
    location /delete-message {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
```

### Testar e recarregar

```bash
nginx -t
systemctl reload nginx
```

### Testar endpoint

```bash
# Testar localmente no servidor
curl -X POST http://127.0.0.1:3001/delete-message \
  -H 'Content-Type: application/json' \
  -d '{"mensagem_id": "test-id"}'

# Testar via HTTPS (do Windows)
curl -X POST https://api.taskflowv3.com.br/delete-message \
  -H 'Content-Type: application/json' \
  -d '{"mensagem_id": "test-id"}'
```

## Solução 2: Telegram → Flutter (Limitação da Bot API)

**PROBLEMA**: A Bot API do Telegram **não envia updates** quando mensagens são deletadas manualmente pelo usuário. Isso é uma limitação conhecida da API.

### Opções de Solução

#### Opção A: Aceitar a limitação (Recomendado para agora)
- Mensagens deletadas manualmente no Telegram não sincronizam automaticamente
- Usuários podem deletar no Flutter para sincronizar

#### Opção B: Implementar MTProto/Userbot (Avançado)
- Usar biblioteca como `gramjs` ou `telethon` para receber `UpdateDeleteMessages`
- Requer implementação de userbot (conta de usuário, não bot)
- Mais complexo e pode violar termos de serviço do Telegram

#### Opção C: Comando/Botão "Excluir" (Intermediário)
- Adicionar comando `/delete <message_id>` ou botão inline
- Bot executa a exclusão quando solicitado
- Ainda não resolve exclusões manuais

### Implementação Futura (MTProto)

Se quiser implementar MTProto no futuro:

```javascript
// Exemplo de handler (futuro)
if (update instanceof UpdateDeleteMessages) {
  for (const messageId of update.messages) {
    await processDeletedMessage({
      message_id: messageId,
      chat: { id: update.chatId },
      message_thread_id: update.messageThreadId,
    });
  }
}
```

## Verificação

### 1. Verificar Nginx

```bash
grep -A 5 "location /delete-message" /etc/nginx/sites-enabled/supabase
```

### 2. Verificar logs ao deletar no Flutter

```bash
journalctl -u telegram-webhook -f
```

**Deve aparecer:**
- `🗑️ Recebida requisição /delete-message`
- `🗑️ [deleteMessageEverywhere] Deletando no Telegram`
- `✅ [deleteMessageEverywhere] Mensagem deletada no Telegram`

### 3. Testar no Flutter

1. Envie uma mensagem no Flutter
2. Verifique se aparece no Telegram
3. Delete a mensagem no Flutter
4. Verifique se foi deletada no Telegram

## Checklist

- [ ] Nginx tem `location /delete-message` configurado
- [ ] Nginx foi recarregado
- [ ] Endpoint `/delete-message` responde (teste com curl)
- [ ] Logs mostram deleção no Telegram quando deleta no Flutter
- [ ] Entendido que Telegram → Flutter tem limitação da Bot API
