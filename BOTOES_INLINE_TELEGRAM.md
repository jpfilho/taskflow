# Botões Inline para Selecionar Nota/Ordem no Telegram

## 🎯 Funcionalidade Implementada

Agora quando você envia uma mensagem no Telegram sem tag, o bot automaticamente envia botões inline para você selecionar a Nota ou Ordem vinculada à tarefa!

## 📱 Como Funciona

### 1. Usuário Envia Mensagem

**Telegram:**
```
Verifiquei tudo
```

### 2. Bot Responde com Botões

O bot automaticamente envia uma mensagem de resposta com botões:

```
🏷️ Vincular mensagem a:

📌 Notas:
[📌 11469911] [📌 11469912] [📌 11469913]

🧾 Ordens:
[🧾 67890] [🧾 67891]

[📋 Geral] [❌ Cancelar]
```

### 3. Usuário Clica no Botão

Ao clicar em um botão (ex: `📌 11469911`):
- ✅ Mensagem é vinculada à Nota
- ✅ Badge aparece no Flutter
- ✅ Mensagem de botões é atualizada: "✅ Mensagem vinculada a NOTA 11469911"

## 🎨 Interface Visual

### Mensagem Original

```
┌─────────────────────────────┐
│ João Silva                  │
│ Verifiquei tudo             │
│ 10:30                       │
└─────────────────────────────┘
```

### Mensagem de Botões (Automática)

```
┌─────────────────────────────┐
│ Bot                         │
│ 🏷️ Vincular mensagem a:     │
│                             │
│ 📌 Notas:                   │
│ [📌 11469911] [📌 11469912] │
│                             │
│ [📋 Geral] [❌ Cancelar]   │
└─────────────────────────────┘
```

### Após Selecionar

```
┌─────────────────────────────┐
│ Bot                         │
│ ✅ Mensagem vinculada a     │
│    NOTA 11469911            │
└─────────────────────────────┘
```

## 🔄 Fluxo Técnico

```
1. Usuário envia mensagem no Telegram
   └─ processMessage()
       ├─ Detecta que não tem tag (refType = 'GERAL')
       ├─ Salva mensagem no Supabase
       └─ enviarBotoesSelecaoTag()
           ├─ Busca notas/ordens da tarefa
           ├─ Cria botões inline
           └─ Envia mensagem com botões

2. Usuário clica no botão
   └─ processCallbackQuery()
       ├─ Extrai tipo e ID (tag_nota_<id>)
       ├─ vincularTagMensagem()
       │   ├─ Busca mensagem no banco
       │   ├─ Atualiza ref_type, ref_id, ref_label
       │   └─ Remove botões da mensagem
       └─ Responde ao callback (remove loading)
```

## 📋 Estrutura dos Botões

### Botões de Notas

```javascript
[
  { text: '📌 Notas:', callback_data: 'tag_header_notas' },
  [
    { text: '📌 11469911', callback_data: 'tag_nota_<uuid>' },
    { text: '📌 11469912', callback_data: 'tag_nota_<uuid>' },
    { text: '📌 11469913', callback_data: 'tag_nota_<uuid>' },
  ],
]
```

### Botões de Ordens

```javascript
[
  { text: '🧾 Ordens:', callback_data: 'tag_header_ordens' },
  [
    { text: '🧾 67890', callback_data: 'tag_ordem_<uuid>' },
    { text: '🧾 67891', callback_data: 'tag_ordem_<uuid>' },
  ],
]
```

### Botões de Ação

```javascript
[
  { text: '📋 Geral', callback_data: 'tag_geral' },
  { text: '❌ Cancelar', callback_data: 'tag_cancel' },
]
```

## ✅ Casos de Uso

### Caso 1: Selecionar Nota

1. Usuário envia: "Verifiquei tudo"
2. Bot envia botões
3. Usuário clica em "📌 11469911"
4. Mensagem é vinculada à Nota
5. Badge aparece no Flutter

### Caso 2: Selecionar Ordem

1. Usuário envia: "Ordem executada"
2. Bot envia botões
3. Usuário clica em "🧾 67890"
4. Mensagem é vinculada à Ordem
5. Badge aparece no Flutter

### Caso 3: Marcar como Geral

1. Usuário envia: "Mensagem geral"
2. Bot envia botões
3. Usuário clica em "📋 Geral"
4. Mensagem permanece como GERAL
5. Botões são removidos

### Caso 4: Cancelar

1. Usuário envia: "Teste"
2. Bot envia botões
3. Usuário clica em "❌ Cancelar"
4. Mensagem permanece como GERAL
5. Botões são removidos

### Caso 5: Sem Notas/Ordens

1. Usuário envia: "Mensagem"
2. Bot verifica: não há notas/ordens
3. Bot não envia botões (não há nada para selecionar)

## 🎯 Vantagens

1. ✅ **Automático:** Botões aparecem automaticamente
2. ✅ **Visual:** Interface clara e intuitiva
3. ✅ **Rápido:** Um clique para vincular
4. ✅ **Organizado:** Agrupa notas e ordens separadamente
5. ✅ **Flexível:** Permite cancelar ou marcar como Geral

## ⚠️ Limitações

1. ⚠️ **Máximo 3 botões por linha:** Para não poluir a interface
2. ⚠️ **Apenas tarefas com notas/ordens:** Se não houver, não envia botões
3. ⚠️ **Mensagem separada:** Botões aparecem em mensagem de resposta (não na original)

## 💻 Implementação Técnica

### Função `enviarBotoesSelecaoTag`

```javascript
async function enviarBotoesSelecaoTag(chatId, originalMessageId, topicId, taskId, mensagemId) {
  // 1. Buscar notas/ordens da tarefa
  // 2. Criar botões inline
  // 3. Enviar mensagem com botões
  // 4. Salvar ID da mensagem de botões no metadata
}
```

### Função `processCallbackQuery`

```javascript
async function processCallbackQuery(callbackQuery) {
  // 1. Extrair tipo e ID do callback_data
  // 2. Chamar vincularTagMensagem()
  // 3. Remover botões
  // 4. Responder ao callback
}
```

### Função `vincularTagMensagem`

```javascript
async function vincularTagMensagem(chatId, messageId, topicId, userId, refType, refId) {
  // 1. Buscar mensagem no banco
  // 2. Buscar número da nota/ordem
  // 3. Atualizar mensagem no Supabase
  // 4. Remover botões da mensagem
}
```

## 📝 Formato do callback_data

- `tag_nota_<uuid>`: Vincula à Nota com ID especificado
- `tag_ordem_<uuid>`: Vincula à Ordem com ID especificado
- `tag_geral`: Marca como Geral
- `tag_cancel`: Cancela seleção
- `tag_header_notas`: Header (não faz nada)
- `tag_header_ordens`: Header (não faz nada)

## ✅ Status

- ✅ **Node.js:** Implementado
- ✅ **Botões inline:** Funcionando
- ✅ **Callback queries:** Processados
- ✅ **Atualização:** Mensagem atualizada no Supabase
- ✅ **Feedback visual:** Botões removidos após seleção

**Pronto para usar!** 🚀

## 🧪 Teste

1. Envie uma mensagem no Telegram sem tag
2. Verifique se botões aparecem automaticamente
3. Clique em uma Nota ou Ordem
4. Verifique se badge aparece no Flutter
5. Verifique se mensagem de botões é atualizada
