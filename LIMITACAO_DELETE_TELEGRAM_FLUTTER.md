# Limitação: Deleção no Telegram → Flutter

## Problema

**Status Atual:**
- ✅ **Flutter → Telegram:** Funcionando perfeitamente
- ❌ **Telegram → Flutter:** Não funciona

Quando você deleta uma mensagem no Telegram, ela **não é deletada automaticamente no Flutter**.

## Causa Raiz

A **Telegram Bot API não envia updates** quando mensagens são deletadas manualmente pelo usuário. Isso é uma limitação da API oficial do Telegram.

**Documentação Oficial:**
> "The Bot API does not send updates when messages are deleted manually by users."

## Soluções Possíveis

### 1. **Aceitar a Limitação (Recomendado para MVP)**

Esta é a abordagem mais simples e estável. A maioria dos bots do Telegram funciona assim:
- Mensagens deletadas no bot não são deletadas no sistema principal
- Mensagens deletadas no sistema principal são deletadas no bot

**Vantagens:**
- ✅ Sem complexidade adicional
- ✅ Sem dependências externas
- ✅ Estável e confiável

**Desvantagens:**
- ❌ Deleção não é bidirecional completa

### 2. **Polling Periódico (Não Recomendado)**

Verificar periodicamente se mensagens ainda existem no Telegram:

```javascript
// A cada X minutos, verificar se mensagens ainda existem
async function checkDeletedMessages() {
  // Buscar todas as mensagens com log de entrega
  const { data: logs } = await supabase
    .from('telegram_delivery_logs')
    .select('telegram_chat_id, telegram_message_id, mensagem_id')
    .eq('status', 'sent');
  
  for (const log of logs) {
    // Tentar buscar a mensagem no Telegram
    const response = await fetch(
      `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChat?chat_id=${log.telegram_chat_id}`
    );
    // Se não conseguir, pode ter sido deletada
  }
}
```

**Problemas:**
- ❌ Muito ineficiente (muitas requisições)
- ❌ Pode exceder rate limits do Telegram
- ❌ Não há API para verificar se mensagem específica existe
- ❌ Delay entre deleção e detecção

### 3. **MTProto/Userbot (Complexo)**

Usar a biblioteca MTProto para conectar como usuário (não bot):

**Requisitos:**
- Biblioteca MTProto (ex: `telegram-mtproto` para Node.js)
- Autenticação de usuário (não bot)
- Gerenciamento de sessão
- Mais complexo de manter

**Vantagens:**
- ✅ Recebe todos os updates, incluindo deleções
- ✅ Deleção bidirecional completa

**Desvantagens:**
- ❌ Muito mais complexo
- ❌ Requer autenticação de usuário
- ❌ Pode violar ToS do Telegram se não usado corretamente
- ❌ Mais difícil de manter

### 4. **Webhook Externo ou Serviço de Terceiros**

Usar serviços que monitoram grupos Telegram:

**Exemplos:**
- Telegram Client API (não oficial)
- Serviços de monitoramento de grupos

**Problemas:**
- ❌ Dependência externa
- ❌ Pode não ser confiável
- ❌ Custo adicional

## Recomendação

**Para o momento, recomendo aceitar a limitação** e focar em:
1. ✅ Garantir que Flutter → Telegram funciona perfeitamente (já funciona)
2. ✅ Documentar claramente a limitação para usuários
3. ✅ Considerar implementar MTProto no futuro se for crítico

## Código Atual

O código já está preparado para receber notificações de deleção:

**Endpoint:** `/telegram-message-deleted`
**Função:** `processDeletedMessage()`

Mas esses só funcionarão se:
- Implementarmos MTProto/userbot, OU
- Recebermos notificações de outra fonte

## Workaround Manual

Se for necessário deletar uma mensagem que foi deletada no Telegram:

1. **Via SQL:**
   ```sql
   UPDATE mensagens 
   SET deleted_at = NOW(), deleted_by = 'telegram'
   WHERE id = '<mensagem_id>';
   ```

2. **Via Flutter:**
   - Usuário pode deletar manualmente no app
   - O app já tem a funcionalidade de deleção

## Conclusão

A limitação é **técnica e conhecida** da Telegram Bot API. A solução mais prática é aceitar que:
- ✅ Deleção Flutter → Telegram funciona
- ❌ Deleção Telegram → Flutter não funciona automaticamente

Isso é comum em bots do Telegram e não é considerado um bug, mas sim uma limitação da API.
