# Exemplo Visual: Seleção de Tags Nota/Ordem

## 🎨 Interface Proposta

### Estado Inicial (Geral)

```
┌─────────────────────────────────────┐
│ Chat da Tarefa                      │
├─────────────────────────────────────┤
│ [Mensagens do chat...]              │
│                                     │
├─────────────────────────────────────┤
│ 💬 GERAL ▼                          │ ← Badge clicável
│                                     │
│ ┌───────────────────────────────┐ │
│ │ [📎] [Digite uma mensagem...]   │ │
│ │        [😀] [📤]                │ │
│ └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Ao Clicar no Badge

```
┌─────────────────────────────────────┐
│ Vincular mensagem a                  │
├─────────────────────────────────────┤
│                                     │
│ Tipo:                               │
│ ┌──────┐ ┌──────┐ ┌──────┐         │
│ │ 💬   │ │ 📌   │ │ 🧾   │         │
│ │GERAL │ │ NOTA │ │ORDEM │         │
│ └──────┘ └──────┘ └──────┘         │
│                                     │
│ Selecionar Nota:                    │
│ ┌─────────────────────────────────┐ │
│ │ 📌 NOTA 12345                   │ │
│ │    Descrição da nota...         │ │
│ ├─────────────────────────────────┤ │
│ │ 📌 NOTA 12346                   │ │
│ │    Outra descrição...           │ │
│ └─────────────────────────────────┘ │
│                                     │
│          [Cancelar] [Confirmar]      │
└─────────────────────────────────────┘
```

### Após Selecionar Nota

```
┌─────────────────────────────────────┐
│ Chat da Tarefa                      │
├─────────────────────────────────────┤
│ [Mensagens do chat...]              │
│                                     │
├─────────────────────────────────────┤
│ 📌 NOTA 12345 ▼                     │ ← Badge atualizado
│                                     │
│ ┌───────────────────────────────┐ │
│ │ [📎] [Digite uma mensagem...]   │ │
│ │        [😀] [📤]                │ │
│ └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Mensagem Enviada com Tag

```
┌─────────────────────────────────────┐
│ Chat da Tarefa                      │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 📌 NOTA 12345                    │ │ ← Badge na mensagem
│ │ João Silva                       │ │
│ │ Verifiquei a nota e está OK      │ │
│ │ 10:30                            │ │
│ └─────────────────────────────────┘ │
│                                     │
├─────────────────────────────────────┤
│ 📌 NOTA 12345 ▼                     │ ← Badge mantido para próxima
│ ┌───────────────────────────────┐ │
│ │ [📎] [Digite uma mensagem...]   │ │
│ └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

## 🔄 Fluxo Completo

### 1. Usuário Abre Chat
```
Sistema:
  ├─ Carrega mensagens do chat
  ├─ Obtém grupo_id → tarefa_id
  └─ Carrega notas/ordens da tarefa
     └─ Armazena em _notasDisponiveis e _ordensDisponiveis
```

### 2. Usuário Clica no Badge "GERAL"
```
Ação:
  └─ Abre dialog de seleção
     ├─ Mostra 3 opções: Geral / Nota / Ordem
     └─ Se selecionar Nota/Ordem:
        └─ Mostra lista de notas/ordens disponíveis
```

### 3. Usuário Seleciona "NOTA" e Escolhe "NOTA 12345"
```
Estado Atualizado:
  ├─ _selectedRefType = 'NOTA'
  ├─ _selectedRefId = 'uuid-da-nota-12345'
  └─ _selectedRefLabel = 'NOTA 12345'
  
UI:
  └─ Badge muda de "💬 GERAL" para "📌 NOTA 12345"
```

### 4. Usuário Digita e Envia Mensagem
```
Payload Enviado:
  {
    "grupo_id": "...",
    "conteudo": "Verifiquei a nota...",
    "ref_type": "NOTA",
    "ref_id": "uuid-da-nota-12345",
    "ref_label": "NOTA 12345"
  }
  
Telegram Recebe:
  📌 NOTA 12345
  
  Verifiquei a nota e está tudo correto
```

### 5. Mensagem Aparece no Chat
```
Mensagem Exibida:
  ┌─────────────────────────────┐
  │ 📌 NOTA 12345               │ ← Badge visual
  │ João Silva                  │
  │ Verifiquei a nota...        │
  │ 10:30                       │
  └─────────────────────────────┘
```

## 🎯 Comportamento Esperado

### Badge Persiste Entre Mensagens
- ✅ Se selecionar "NOTA 12345", o badge permanece
- ✅ Próxima mensagem também será "NOTA 12345"
- ✅ Usuário pode mudar a qualquer momento clicando no badge

### Se Não Houver Notas/Ordens
- ✅ Badge não aparece (ou aparece apenas "GERAL")
- ✅ Dialog mostra "Nenhuma nota/ordem vinculada"
- ✅ Usuário só pode selecionar "GERAL"

### Reset Automático (Opcional)
- ⚠️ Após enviar mensagem, pode resetar para "GERAL"
- ⚠️ Ou manter a seleção para facilitar envio de múltiplas mensagens com mesma tag

## 📱 Alternativa: UI Mais Simples

Se preferir uma interface mais simples, pode usar apenas **dois dropdowns lado a lado**:

```
┌─────────────────────────────────────┐
│ [💬 Geral ▼] [Selecionar Nota ▼]    │ ← Dropdowns inline
│                                     │
│ ┌───────────────────────────────┐ │
│ │ [📎] [Digite...] [😀] [📤]     │ │
│ └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Vantagem:** Mais compacto, menos cliques  
**Desvantagem:** Menos visual, pode ser menos intuitivo

## ✅ Recomendação

**Usar a abordagem com Badge + Dialog** porque:
1. ✅ Mais visual e intuitivo
2. ✅ Feedback claro do que está selecionado
3. ✅ Não ocupa espaço quando não necessário
4. ✅ Permite ver descrição das notas/ordens antes de selecionar

Quer que eu implemente isso no código agora?
