# Como Funciona: Seleção de Tags Nota/Ordem

## 🎯 Experiência do Usuário

### Cenário 1: Mensagem Geral (Padrão)

1. **Usuário abre o chat** → Vê badge "💬 GERAL"
2. **Usuário digita mensagem** → "Olá, tudo bem?"
3. **Usuário pressiona Enter ou clica em enviar**
4. **Mensagem é enviada** → Aparece no chat e no Telegram como "💬 GERAL"

### Cenário 2: Mensagem com Nota

1. **Usuário abre o chat** → Sistema carrega automaticamente as notas da tarefa
2. **Usuário vê badge "💬 GERAL"** → Clica no badge
3. **Abre dialog de seleção:**
   ```
   ┌─────────────────────────────┐
   │ Vincular mensagem a         │
   ├─────────────────────────────┤
   │ [💬 Geral] [📌 Nota] [🧾 Ordem] │
   │                             │
   │ Selecionar Nota:           │
   │ • 📌 NOTA 12345            │
   │ • 📌 NOTA 12346            │
   │ • 📌 NOTA 12347            │
   └─────────────────────────────┘
   ```
4. **Usuário seleciona "NOTA"** → Lista de notas aparece
5. **Usuário seleciona "NOTA 12345"** → Clica "Confirmar"
6. **Badge muda para "📌 NOTA 12345"**
7. **Usuário digita** → "Verifiquei a nota, está tudo OK"
8. **Usuário envia** → Mensagem vai com tag "NOTA 12345"
9. **No Telegram aparece:**
   ```
   📌 NOTA 12345
   
   Verifiquei a nota, está tudo OK
   ```

### Cenário 3: Múltiplas Mensagens com Mesma Tag

1. **Usuário seleciona "NOTA 12345"** (como no cenário 2)
2. **Envia primeira mensagem** → "Verifiquei a nota"
3. **Badge permanece "📌 NOTA 12345"** ← **Mantém seleção!**
4. **Usuário envia segunda mensagem** → "Fotos anexadas"
5. **Ambas as mensagens** têm a tag "NOTA 12345"
6. **Usuário pode mudar a tag** a qualquer momento clicando no badge

### Cenário 4: Sem Notas/Ordens Disponíveis

1. **Usuário abre o chat** → Sistema tenta carregar notas/ordens
2. **Não há notas/ordens vinculadas** → Badge mostra apenas "💬 GERAL"
3. **Ao clicar no badge** → Dialog mostra:
   ```
   ┌─────────────────────────────┐
   │ Vincular mensagem a         │
   ├─────────────────────────────┤
   │ [💬 Geral] [📌 Nota] [🧾 Ordem] │
   │                             │
   │ Selecionar Nota:           │
   │ Nenhuma nota vinculada     │
   │ a esta tarefa               │
   └─────────────────────────────┘
   ```
4. **Usuário só pode selecionar "GERAL"**

## 🔄 Fluxo Técnico Completo

### 1. Carregamento Inicial

```
ChatScreen.initState()
  └─ _carregarNotasEOrdens()
      ├─ Obter grupo → tarefa_id
      ├─ Buscar notas: tasks_notas_sap → notas_sap
      └─ Buscar ordens: tasks_ordens → ordens
      └─ Armazenar em _notasDisponiveis e _ordensDisponiveis
```

### 2. Seleção de Tag

```
Usuário clica no badge
  └─ _mostrarSeletorTag()
      └─ Dialog com:
          ├─ Seleção de tipo (Geral/Nota/Ordem)
          └─ Se Nota/Ordem: Lista de opções
      └─ Usuário confirma
          └─ Atualiza estado:
              ├─ _selectedRefType
              ├─ _selectedRefId
              └─ _selectedRefLabel
```

### 3. Envio de Mensagem

```
Usuário digita e envia
  └─ _enviarMensagem()
      ├─ Salva no Supabase com tags:
      │   ├─ ref_type
      │   ├─ ref_id
      │   └─ ref_label
      └─ Envia para Node.js com tags:
          └─ Node.js formata Telegram:
              ├─ Se NOTA: "📌 NOTA 12345\n\n{conteudo}"
              ├─ Se ORDEM: "🧾 ORDEM 67890\n\n{conteudo}"
              └─ Se GERAL: "💬 GERAL\n\n{conteudo}"
```

## 📱 Interface Visual Detalhada

### Estado Inicial

```
┌─────────────────────────────────────┐
│ Chat: Tarefa XYZ                     │
├─────────────────────────────────────┤
│ [Mensagens anteriores...]           │
│                                     │
├─────────────────────────────────────┤
│ 💬 GERAL ▼                          │ ← Badge clicável
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ [📎] [Digite uma mensagem...]     │ │
│ │        [😀] [📤]                  │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Após Selecionar Nota

```
┌─────────────────────────────────────┐
│ Chat: Tarefa XYZ                     │
├─────────────────────────────────────┤
│ [Mensagens anteriores...]           │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 📌 NOTA 12345                   │ │ ← Mensagem com tag
│ │ João Silva                      │ │
│ │ Verifiquei a nota...            │ │
│ └─────────────────────────────────┘ │
│                                     │
├─────────────────────────────────────┤
│ 📌 NOTA 12345 ▼                    │ ← Badge mantido
│ ┌─────────────────────────────────┐ │
│ │ [📎] [Digite uma mensagem...]     │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Dialog de Seleção

```
┌─────────────────────────────────────┐
│ Vincular mensagem a                │
├─────────────────────────────────────┤
│                                     │
│ Tipo:                               │
│ ┌────────┐ ┌────────┐ ┌────────┐   │
│ │  💬    │ │  📌    │ │  🧾    │   │
│ │ GERAL  │ │ NOTA   │ │ ORDEM  │   │
│ │ (✓)    │ │        │ │        │   │
│ └────────┘ └────────┘ └────────┘   │
│                                     │
│ Selecionar Nota:                    │
│ ┌─────────────────────────────────┐ │
│ │ ○ 📌 NOTA 12345                 │ │
│ │    Descrição da nota...        │ │
│ ├─────────────────────────────────┤ │
│ │ ● 📌 NOTA 12346                 │ │ ← Selecionada
│ │    Outra descrição...          │ │
│ ├─────────────────────────────────┤ │
│ │ ○ 📌 NOTA 12347                 │ │
│ │    Mais uma...                 │ │
│ └─────────────────────────────────┘ │
│                                     │
│     [Cancelar]    [Confirmar]       │
└─────────────────────────────────────┘
```

## ✅ Comportamentos Importantes

### Badge Persiste Entre Mensagens
- ✅ Se selecionar "NOTA 12345", o badge permanece
- ✅ Próxima mensagem também será "NOTA 12345"
- ✅ Facilita enviar múltiplas mensagens sobre a mesma nota/ordem

### Reset Automático (Opcional)
- ⚠️ Pode resetar para "GERAL" após enviar (menos conveniente)
- ✅ **Recomendado:** Manter seleção para facilitar uso

### Carregamento Automático
- ✅ Notas/ordens carregam ao abrir o chat
- ✅ Se não houver, badge mostra apenas "GERAL"
- ✅ Se houver, opções aparecem no dialog

### Feedback Visual
- ✅ Badge colorido: Azul=Nota, Verde=Ordem, Cinza=Geral
- ✅ Ícone diferente para cada tipo
- ✅ Label mostra identificador (ex: "NOTA 12345")

## 🎯 Vantagens desta Abordagem

1. **Intuitivo:** Badge mostra claramente o que está selecionado
2. **Não intrusivo:** Ocupa pouco espaço
3. **Flexível:** Usuário pode mudar a qualquer momento
4. **Eficiente:** Carrega notas/ordens uma vez ao abrir chat
5. **Compatível:** Funciona mesmo sem notas/ordens

## 📝 Próximos Passos de Implementação

1. ✅ Modelo `Mensagem` atualizado (campos de tag adicionados)
2. ⏭️ Adicionar variáveis de estado no `ChatScreen`
3. ⏭️ Implementar `_carregarNotasEOrdens()`
4. ⏭️ Criar widget `_buildTagSelector()`
5. ⏭️ Criar dialog `_TagSelectorDialog`
6. ⏭️ Atualizar `ChatService.enviarMensagem()` para aceitar tags
7. ⏭️ Atualizar `TelegramService.sendMessageToTelegram()` para enviar tags
8. ⏭️ Atualizar Node.js `/send-message` para processar tags
9. ⏭️ Exibir badge nas mensagens no chat

Quer que eu implemente isso agora no código?
