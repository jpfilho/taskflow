# Resumo: Exclusão Bidirecional Flutter ↔ Telegram

## Status Atual

### ✅ Funcionando
1. **Flutter → Telegram (envio)**: Mensagens são enviadas e aparecem no Telegram
2. **Telegram → Flutter (recebimento)**: Mensagens do Telegram aparecem no chat
3. **Webhook configurado**: Telegram envia updates para o servidor
4. **Logs de entrega**: Mensagens têm `telegram_delivery_logs` criados

### ⚠️ Parcialmente Funcionando
1. **Flutter → Telegram (exclusão)**: 
   - Endpoint `/delete-message` configurado no Nginx
   - Código trata mensagens sem log de entrega
   - **Problema**: Mensagem removida da UI mas não deletada no banco em alguns casos

### ❌ Não Funcionando
1. **Telegram → Flutter (exclusão)**: 
   - Limitação da Bot API: não recebe updates quando mensagens são deletadas manualmente
   - Solução: Aceitar limitação ou implementar MTProto/userbot (complexo)

## Correções Implementadas

### 1. Node.js (`telegram-webhook-server-generalized.js`)
- ✅ Trata mensagens sem log de entrega como normal
- ✅ Sempre faz soft delete no Supabase
- ✅ Trata mensagens já deletadas no Telegram como sucesso
- ✅ Retorna informações detalhadas (`reason`, `info`, `warning`)

### 2. Flutter (`chat_service.dart`)
- ✅ Verifica se soft delete foi aplicado
- ✅ Faz fallback se Node.js não aplicar soft delete
- ✅ Filtra mensagens deletadas no stream

### 3. Flutter (`telegram_service.dart`)
- ✅ Mostra mensagens informativas (não erros) quando não havia no Telegram
- ✅ Trata `deletedCount: 0` como informativo, não erro

### 4. Nginx
- ✅ `location /send-message` configurado
- ✅ `location /telegram-webhook` configurado
- ⚠️ `location /delete-message` precisa ser adicionado

## Problemas Identificados

### Problema 1: Mensagem removida da UI mas não deletada no banco
**Causa**: O Flutter remove da UI antes de confirmar que a deleção foi bem-sucedida.

**Solução**: Código já corrigido para verificar soft delete e fazer fallback.

### Problema 2: Constraint `deleted_by` não permite `'manual'`
**Causa**: Constraint permite apenas `'flutter'`, `'telegram'` ou UUID.

**Solução**: Usar `'flutter'` ao invés de `'manual'` em queries SQL.

### Problema 3: Mensagem já deletada no Telegram
**Causa**: Quando mensagem já foi deletada manualmente no Telegram, API retorna erro.

**Solução**: Código atualizado para tratar como sucesso (mensagem já não existe).

## Próximos Passos

### 1. Fazer Deploy do Node.js Atualizado
```powershell
.\deploy_nodejs_rapido.ps1
```

### 2. Adicionar `/delete-message` no Nginx (se ainda não estiver)
```bash
# No servidor
grep -A 10 "location /delete-message" /etc/nginx/sites-enabled/supabase
```

Se não existir, adicionar conforme `CORRIGIR_DELETE_BIDIRECIONAL.md`.

### 3. Testar com Nova Mensagem
1. Envie uma nova mensagem no Flutter
2. Verifique se aparece no Telegram
3. Delete a mensagem no Flutter
4. Verifique se foi deletada no Telegram também

### 4. Verificar Logs
```bash
ssh root@212.85.0.249 'journalctl -u telegram-webhook -f'
```

## Checklist Final

- [ ] Node.js atualizado no servidor (com correções)
- [ ] Nginx tem `location /delete-message` configurado
- [ ] Flutter atualizado (com verificações de soft delete)
- [ ] Teste com mensagem que tem log de entrega
- [ ] Verificar se `deletedFromTelegram: 1` nos logs
- [ ] Verificar se mensagem foi deletada no Telegram

## Comandos Úteis

### Verificar mensagem no banco
```sql
SELECT id, conteudo, deleted_at, deleted_by, source
FROM mensagens
WHERE id = '<mensagem_id>';
```

### Verificar log de entrega
```sql
SELECT dl.*
FROM telegram_delivery_logs dl
WHERE dl.mensagem_id = '<mensagem_id>';
```

### Verificar logs do servidor
```bash
journalctl -u telegram-webhook -n 50 --no-pager | grep "deleteMessageEverywhere"
```
