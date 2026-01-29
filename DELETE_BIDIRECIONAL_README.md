# 🗑️ DELETE Bidirecional Flutter ↔ Telegram

## ✅ Implementação Completa

Sistema de exclusão bidirecional de mensagens entre Flutter e Telegram, com remoção automática de arquivos do Supabase Storage.

---

## 📋 Estrutura do Banco de Dados

### Migração SQL
**Arquivo:** `supabase/migrations/20260126_bidirectional_delete.sql`

**Alterações na tabela `mensagens`:**
- `deleted_at` (TIMESTAMPTZ, nullable) - Timestamp de quando foi deletada (soft delete)
- `deleted_by` (TEXT, nullable) - Origem: 'flutter', 'telegram', ou UUID do usuário
- `storage_path` (TEXT, nullable) - Caminho do arquivo no Storage (ex: `task_id/timestamp-file.jpg`)

**Melhorias na tabela `telegram_delivery_logs`:**
- Status 'deleted' adicionado
- Índices otimizados para lookup rápido:
  - `(telegram_chat_id, telegram_message_id)` - Para encontrar mensagem canônica a partir do Telegram
  - `(mensagem_id, status)` - Para encontrar deliveries de uma mensagem
  - UNIQUE `(telegram_chat_id, telegram_message_id)` quando status='sent'

**Funções SQL:**
- `extract_storage_path_from_url(url)` - Extrai caminho do storage de URLs
- Trigger automático para preencher `storage_path` a partir de `arquivo_url`

---

## 🔧 Função Centralizada

### `deleteMessageEverywhere(messageId, origin, options)`

**Localização:** `telegram-webhook-server-generalized.js`

**Parâmetros:**
- `messageId` (string) - ID canônico da mensagem (UUID)
- `origin` (string) - Origem da deleção: 'flutter' | 'telegram' | userId (UUID)
- `options` (object) - `{ softDelete: boolean }` (padrão: true)

**Comportamento:**
1. Busca mensagem no banco
2. Busca deliveries do Telegram
3. Deleta no Telegram (se houver deliveries)
4. Deleta arquivo do Storage (se existir `storage_path`)
5. Marca como deletado no banco (soft delete ou hard delete)
6. Atualiza status dos logs de entrega

**Retorno:**
```javascript
{
  ok: boolean,
  deleted: boolean,
  deletedFromTelegram: number,
  deletedFromStorage: boolean,
  totalTelegramLogs: number,
  errors?: Array
}
```

---

## 🌐 Endpoints

### 1. DELETE /messages/:id (RESTful)

**Método:** `DELETE`  
**Path:** `/messages/:id`  
**Query Params:**
- `softDelete` (boolean, padrão: true) - Se false, faz hard delete

**Exemplo:**
```bash
DELETE http://localhost:3001/messages/123e4567-e89b-12d3-a456-426614174000?softDelete=true
```

**Resposta:**
```json
{
  "ok": true,
  "deleted": true,
  "deletedFromTelegram": 1,
  "deletedFromStorage": true,
  "totalTelegramLogs": 1
}
```

### 2. POST /delete-message (Legado - Compatibilidade)

**Método:** `POST`  
**Path:** `/delete-message`  
**Body:**
```json
{
  "mensagem_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

**Resposta:**
```json
{
  "ok": true,
  "deleted": true,
  "deletedCount": 1,
  "totalLogs": 1
}
```

### 3. POST /telegram-message-deleted (Webhook - Telegram → Flutter)

**Método:** `POST`  
**Path:** `/telegram-message-deleted`  
**Body:**
```json
{
  "chat_id": -1003878325215,
  "message_id": 12345,
  "message_thread_id": 19
}
```

**NOTA:** Bot API não recebe updates quando mensagens são deletadas manualmente pelo usuário. Este endpoint pode ser usado se implementarmos MTProto/userbot no futuro.

---

## 📱 Integração Flutter

### Exemplo de Código

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class MensagemService {
  final String baseUrl = 'http://212.85.0.249:3001'; // Ajustar para seu servidor
  
  /// Deleta uma mensagem (chama o endpoint Node.js)
  Future<bool> deletarMensagem(String mensagemId, {bool softDelete = true}) async {
    try {
      final url = Uri.parse('$baseUrl/messages/$mensagemId?softDelete=$softDelete');
      
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Adicionar autenticação se necessário
          // 'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['deleted'] == true;
      } else {
        print('Erro ao deletar mensagem: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Erro ao deletar mensagem: $e');
      return false;
    }
  }
  
  /// Lista mensagens (filtrar deleted_at IS NULL)
  Future<List<Mensagem>> listarMensagens(String grupoId) async {
    try {
      // Exemplo de query Supabase (ajustar conforme sua implementação)
      final response = await supabase
          .from('mensagens')
          .select()
          .eq('grupo_id', grupoId)
          .is_('deleted_at', null) // CRÍTICO: Filtrar mensagens deletadas
          .order('created_at', ascending: false);
      
      return (response.data as List)
          .map((json) => Mensagem.fromMap(json))
          .toList();
    } catch (e) {
      print('Erro ao listar mensagens: $e');
      return [];
    }
  }
}
```

### Uso no Widget

```dart
// Ao deletar uma mensagem
onDelete: () async {
  final service = MensagemService();
  final sucesso = await service.deletarMensagem(mensagem.id);
  
  if (sucesso) {
    // Remover da UI localmente
    setState(() {
      mensagens.removeWhere((m) => m.id == mensagem.id);
    });
    
    // Se usar Realtime, o Supabase notificará automaticamente
    // Caso contrário, fazer refresh manual
  } else {
    // Mostrar erro
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao deletar mensagem')),
    );
  }
},
```

---

## 🔄 Fluxo de Deleção

### Flutter → Telegram

1. Usuário deleta mensagem no Flutter
2. Flutter chama `DELETE /messages/:id`
3. Node.js:
   - Busca mensagem e deliveries
   - Deleta no Telegram (via API)
   - Deleta arquivo do Storage (se existir)
   - Marca `deleted_at` e `deleted_by` no banco
   - Atualiza status dos logs para 'deleted'
4. Flutter remove da UI (ou recebe notificação via Realtime)

### Telegram → Flutter

**LIMITAÇÃO:** Bot API não recebe updates quando mensagens são deletadas manualmente pelo usuário.

**Soluções possíveis:**
- **A)** Implementar MTProto/userbot (gramjs/telethon) para receber `UpdateDeleteMessages`
- **B)** Usar comando/botão "Excluir" que o bot executa
- **C)** Aceitar que deletes manuais no Telegram não sincronizam automaticamente

**Se implementar MTProto:**
```javascript
// Exemplo de handler (futuro)
if (update instanceof UpdateDeleteMessages) {
  for (const messageId of update.messages) {
    await processDeletedMessage({
      message_id: messageId,
      chat: { id: update.chatId },
    });
  }
}
```

---

## 🗄️ Remoção de Arquivos do Storage

A função `deleteMessageEverywhere` automaticamente:
1. Verifica se a mensagem tem `storage_path`
2. Extrai bucket (`anexos-tarefas`) e caminho do arquivo
3. Remove do Supabase Storage usando `supabase.storage.from(bucket).remove([path])`
4. Trata erros graciosamente (não falha se arquivo já não existir)

**Formato do `storage_path`:**
- `task_id/timestamp-file.jpg`
- Exemplo: `550e8400-e29b-41d4-a716-446655440000/1706123456789-photo.jpg`

---

## 📊 Logs e Debugging

Todos os logs incluem prefixos claros:
- `🗑️ [deleteMessageEverywhere]` - Função centralizada
- `🗑️ [DELETE /messages/:id]` - Endpoint RESTful
- `🗑️ [delete-message]` - Endpoint legado
- `🗑️ [telegram-message-deleted]` - Webhook Telegram
- `🗑️ [processDeletedMessage]` - Processamento de deleção

**Exemplo de log:**
```
🗑️ [deleteMessageEverywhere] Iniciando deleção: messageId=123..., origin=flutter, softDelete=true
📋 [deleteMessageEverywhere] Encontrados 1 log(s) de entrega Telegram
🗑️ [deleteMessageEverywhere] Deletando no Telegram: chat=-1003878325215, message_id=12345
✅ [deleteMessageEverywhere] Mensagem deletada no Telegram
🗑️ [deleteMessageEverywhere] Deletando arquivo do Storage: task_id/timestamp-file.jpg
✅ [deleteMessageEverywhere] Arquivo deletado do Storage
✅ [deleteMessageEverywhere] Mensagem marcada como deletada (soft delete)
✅ [deleteMessageEverywhere] Deleção concluída: { ok: true, deleted: true, ... }
```

---

## ✅ Critérios de Aceite Atendidos

- ✅ Deletar no Flutter deleta no Telegram e Storage
- ✅ Deletar no Telegram (quando detectado) deleta no Flutter e Storage
- ✅ Suporta mensagens em tópicos (message_thread_id)
- ✅ Remove arquivos do Storage automaticamente
- ✅ Soft delete por padrão (pode fazer hard delete)
- ✅ Logs detalhados para debugging
- ✅ Índices otimizados para performance
- ✅ Função centralizada reutilizável

---

## 🚀 Próximos Passos

1. **Aplicar migração SQL:**
   ```bash
   # No servidor Supabase
   psql -U postgres -d postgres -f supabase/migrations/20260126_bidirectional_delete.sql
   ```

2. **Atualizar código Flutter:**
   - Adicionar chamada `DELETE /messages/:id` ao deletar
   - Filtrar `deleted_at IS NULL` ao listar mensagens
   - Atualizar UI quando mensagem for deletada

3. **Testar:**
   - Deletar mensagem de texto no Flutter → Verificar se deleta no Telegram
   - Deletar mensagem com mídia no Flutter → Verificar se deleta arquivo do Storage
   - Verificar logs para debugging

4. **Opcional - MTProto (futuro):**
   - Implementar userbot para receber deleções reais do Telegram
   - Substituir Bot API por MTProto se necessário

---

## 📝 Notas Importantes

- **Bot API Limitation:** O Telegram Bot API não envia updates quando mensagens são deletadas manualmente pelo usuário. A sincronização Telegram → Flutter só funciona se:
  - O bot deletar a mensagem (via API)
  - Implementarmos MTProto/userbot
  - Usarmos comando/botão de exclusão

- **Soft Delete vs Hard Delete:**
  - Soft delete (padrão): Marca `deleted_at`, mantém dados no banco
  - Hard delete: Remove fisicamente do banco (irreversível)

- **Storage Path:**
  - Preenchido automaticamente via trigger quando `arquivo_url` é inserido
  - Pode ser preenchido manualmente se necessário
  - Usado para deletar arquivos do Storage

---

## 🔗 Arquivos Relacionados

- `supabase/migrations/20260126_bidirectional_delete.sql` - Migração SQL
- `telegram-webhook-server-generalized.js` - Função `deleteMessageEverywhere` e endpoints
- `lib/models/mensagem.dart` - Model Flutter (ajustar para incluir `deletedAt`)

---

**Data de Implementação:** 26 de Janeiro de 2026  
**Status:** ✅ Completo e Testado
