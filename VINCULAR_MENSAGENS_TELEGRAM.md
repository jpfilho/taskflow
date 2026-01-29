# Vincular Mensagens do Telegram a Nota/Ordem

## 🎯 Como Funciona

### Mensagens do Telegram

**Comportamento padrão:**
- Mensagens recebidas do Telegram sempre chegam como **GERAL** (sem tag)
- Não podem ser vinculadas a Nota/Ordem no momento do recebimento
- Isso é por design, pois o usuário no Telegram não tem como selecionar a tag

### Vincular Depois (Nova Funcionalidade)

**Agora é possível vincular mensagens do Telegram (ou qualquer mensagem GERAL) a uma Nota/Ordem depois!**

## 📱 Como Usar

### 1. Mensagem do Telegram Chega
```
Telegram → Node.js → Supabase → Flutter
└─ ref_type = 'GERAL'
└─ ref_id = NULL
└─ ref_label = NULL
```

### 2. Usuário Quer Vincular
1. **Long press** na mensagem (pressionar e segurar)
2. Menu de contexto abre
3. Clicar em **"Vincular a Nota/Ordem"** (ou "Alterar vínculo" se já tiver)
4. Dialog de seleção abre (mesmo dialog usado para novas mensagens)
5. Selecionar tipo (Geral/Nota/Ordem)
6. Se Nota/Ordem: Selecionar item específico
7. Clicar "Confirmar"

### 3. Mensagem é Atualizada
```
Supabase:
└─ ref_type = 'NOTA' (ou 'ORDEM')
└─ ref_id = UUID da nota/ordem
└─ ref_label = 'NOTA 12345' (ou 'ORDEM 67890')
```

### 4. Badge Aparece
- Badge de tag aparece na mensagem
- Mensagem fica vinculada à Nota/Ordem selecionada

## 🎨 Interface Visual

### Menu de Contexto (Long Press)

```
┌─────────────────────────────┐
│ [↩️] Responder              │
│ [🏷️] Vincular a Nota/Ordem │ ← Nova opção
│ [✏️] Editar                 │
│ [📤] Compartilhar           │
│ [➡️] Encaminhar             │
│ [🗑️] Excluir                │
└─────────────────────────────┘
```

### Se Já Tiver Vínculo

```
┌─────────────────────────────┐
│ [↩️] Responder              │
│ [🏷️] Alterar vínculo       │ ← Mostra vínculo atual
│     NOTA 12345              │
│ [✏️] Editar                 │
│ ...                         │
└─────────────────────────────┘
```

## 💻 Implementação

### 1. Novo Método no ChatService

```dart
Future<Mensagem> atualizarTagsMensagem(
  String mensagemId, {
  String? refType,
  String? refId,
  String? refLabel,
}) async {
  // Atualiza ref_type, ref_id, ref_label no Supabase
}
```

### 2. Novo Método no ChatScreen

```dart
Future<void> _vincularMensagem(Mensagem mensagem) async {
  // Abre dialog de seleção
  // Atualiza mensagem com novas tags
}
```

### 3. Opção no Menu de Contexto

```dart
ListTile(
  leading: Icon(Icons.label_outline),
  title: Text('Vincular a Nota/Ordem'),
  onTap: () => _vincularMensagem(mensagem),
),
```

## ✅ Casos de Uso

### Caso 1: Mensagem do Telegram
1. Mensagem chega do Telegram como GERAL
2. Usuário faz long press
3. Seleciona "Vincular a Nota/Ordem"
4. Escolhe uma NOTA
5. Mensagem fica vinculada à NOTA

### Caso 2: Mensagem GERAL do Flutter
1. Mensagem foi enviada sem tag (GERAL)
2. Usuário quer vincular depois
3. Faz long press → "Vincular a Nota/Ordem"
4. Escolhe uma ORDEM
5. Mensagem fica vinculada à ORDEM

### Caso 3: Alterar Vínculo Existente
1. Mensagem já tem tag "NOTA 12345"
2. Usuário quer mudar para "ORDEM 67890"
3. Faz long press → "Alterar vínculo"
4. Seleciona ORDEM e escolhe ordem
5. Vínculo é atualizado

### Caso 4: Remover Vínculo
1. Mensagem tem tag "NOTA 12345"
2. Usuário quer remover vínculo
3. Faz long press → "Alterar vínculo"
4. Seleciona GERAL
5. Vínculo é removido (volta para GERAL)

## 🔄 Fluxo Técnico

```
Usuário faz long press
  └─ _mostrarMenuMensagem()
      └─ ListTile "Vincular a Nota/Ordem"
          └─ _vincularMensagem()
              ├─ Abre TagSelectorDialog
              │   └─ Usuário seleciona tipo e item
              └─ ChatService.atualizarTagsMensagem()
                  └─ UPDATE mensagens SET ref_type, ref_id, ref_label
                      └─ Flutter recebe atualização via Realtime
                          └─ Badge aparece na mensagem
```

## 📋 Vantagens

1. ✅ **Flexibilidade:** Permite vincular mensagens depois
2. ✅ **Correção:** Se esqueceu de vincular, pode corrigir
3. ✅ **Organização:** Mensagens do Telegram podem ser organizadas
4. ✅ **Consistência:** Usa o mesmo dialog de seleção
5. ✅ **Visual:** Badge mostra claramente o vínculo

## 🎯 Exemplo Prático

**Cenário:**
- Usuário recebe mensagem no Telegram: "Verifiquei a nota 12345"
- Mensagem chega como GERAL
- Usuário faz long press → "Vincular a Nota/Ordem"
- Seleciona NOTA → Escolhe "NOTA 12345"
- Mensagem fica vinculada e badge aparece

**Resultado:**
- Mensagem mostra badge "NOTA 12345"
- Pode filtrar mensagens por nota
- Organização melhorada

## ✅ Status

- ✅ **Flutter:** Implementado
- ✅ **Supabase:** Suporta UPDATE de tags
- ✅ **Node.js:** Não precisa de mudanças (apenas Flutter atualiza)

**Pronto para usar!** 🚀
