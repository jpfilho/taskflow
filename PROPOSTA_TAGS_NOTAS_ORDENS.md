# Proposta: Tags de Nota/Ordem nas Mensagens

## 📊 Análise do Schema Atual

### Relacionamentos Identificados

```
mensagens
  └─ grupo_id (FK) → grupos_chat.id
      └─ tarefa_id → tasks.id
          ├─ tasks_notas_sap → notas_sap.id
          └─ tasks_ordens → ordens.id
```

### Tabelas Críticas

1. **`mensagens`**: Tabela principal do chat
   - `id` (UUID, PK)
   - `grupo_id` (UUID, FK → grupos_chat)
   - **NÃO tem** `task_id` direto
   - **NÃO tem** campos de tag/referência

2. **`grupos_chat`**: Liga mensagens a tarefas
   - `id` (UUID, PK)
   - `tarefa_id` (UUID, FK → tasks) - **assumido, verificar no banco**

3. **`tasks`**: Tarefas principais
   - `id` (UUID, PK)

4. **`tasks_notas_sap`**: Relacionamento N:N tasks ↔ notas
   - `task_id` (UUID, FK → tasks)
   - `nota_sap_id` (UUID, FK → notas_sap)

5. **`tasks_ordens`**: Relacionamento N:N tasks ↔ ordens
   - `task_id` (UUID, FK → tasks)
   - `ordem_id` (UUID, FK → ordens)

## 🎯 Modelo de Dados Proposto

### Campos a Adicionar em `mensagens`

```sql
-- Tipo de referência: 'GERAL' | 'NOTA' | 'ORDEM'
ref_type TEXT DEFAULT 'GERAL' CHECK (ref_type IN ('GERAL', 'NOTA', 'ORDEM'))

-- ID da nota ou ordem (nullable, preenchido apenas se ref_type != 'GERAL')
ref_id UUID NULL

-- Label para exibição (opcional, pode ser preenchido automaticamente)
ref_label TEXT NULL
```

### Justificativa

- ✅ **Mínima mudança**: Apenas 3 campos opcionais
- ✅ **Compatibilidade total**: Mensagens antigas = `ref_type = 'GERAL'`, `ref_id = NULL`
- ✅ **Sem tabela nova**: Tudo na tabela existente
- ✅ **Índices otimizados**: Para filtros rápidos
- ✅ **Sem FK direta**: Evita problemas de integridade (nota/ordem pode ser deletada)

## 📝 SQL de Migração

```sql
-- ============================================
-- MIGRATION: ADICIONAR TAGS NOTA/ORDEM EM MENSAGENS
-- ============================================
-- Compatível com dados existentes
-- Mensagens antigas serão tratadas como 'GERAL'

-- 1. Adicionar coluna ref_type
ALTER TABLE public.mensagens
  ADD COLUMN IF NOT EXISTS ref_type TEXT DEFAULT 'GERAL'
  CHECK (ref_type IN ('GERAL', 'NOTA', 'ORDEM'));

-- 2. Adicionar coluna ref_id (nullable)
ALTER TABLE public.mensagens
  ADD COLUMN IF NOT EXISTS ref_id UUID NULL;

-- 3. Adicionar coluna ref_label (nullable, para exibição)
ALTER TABLE public.mensagens
  ADD COLUMN IF NOT EXISTS ref_label TEXT NULL;

-- 4. Atualizar mensagens existentes para 'GERAL' (garantir consistência)
UPDATE public.mensagens
SET ref_type = 'GERAL'
WHERE ref_type IS NULL;

-- 5. Criar índice para filtros por tipo de referência
CREATE INDEX IF NOT EXISTS idx_mensagens_ref_type 
  ON public.mensagens(ref_type) 
  WHERE ref_type != 'GERAL';

-- 6. Criar índice composto para filtros por tipo + id
CREATE INDEX IF NOT EXISTS idx_mensagens_ref_type_id 
  ON public.mensagens(ref_type, ref_id) 
  WHERE ref_type != 'GERAL' AND ref_id IS NOT NULL;

-- 7. Criar índice para buscar mensagens de uma nota específica
CREATE INDEX IF NOT EXISTS idx_mensagens_ref_id_nota 
  ON public.mensagens(ref_id) 
  WHERE ref_type = 'NOTA' AND ref_id IS NOT NULL;

-- 8. Criar índice para buscar mensagens de uma ordem específica
CREATE INDEX IF NOT EXISTS idx_mensagens_ref_id_ordem 
  ON public.mensagens(ref_id) 
  WHERE ref_type = 'ORDEM' AND ref_id IS NOT NULL;

-- 9. Comentários para documentação
COMMENT ON COLUMN public.mensagens.ref_type IS 
  'Tipo de referência: GERAL (padrão), NOTA (vinculada a nota_sap), ORDEM (vinculada a ordem)';

COMMENT ON COLUMN public.mensagens.ref_id IS 
  'ID da nota_sap ou ordem referenciada (UUID). NULL se ref_type = GERAL';

COMMENT ON COLUMN public.mensagens.ref_label IS 
  'Label para exibição (ex: "NOTA 12345", "ORDEM 67890"). Opcional, pode ser preenchido automaticamente';
```

## 🔍 Queries de Busca

### Buscar Notas de uma Tarefa

```sql
-- Buscar todas as notas vinculadas a uma tarefa
SELECT 
    ns.id,
    ns.nota,  -- Campo 'nota' é o identificador único (VARCHAR(50))
    ns.descricao,
    COUNT(m.id) AS total_mensagens
FROM tasks_notas_sap tns
JOIN notas_sap ns ON ns.id = tns.nota_sap_id
LEFT JOIN mensagens m ON m.ref_type = 'NOTA' AND m.ref_id = ns.id
WHERE tns.task_id = '<task_id>'
GROUP BY ns.id, ns.nota, ns.descricao
ORDER BY ns.nota;
```

### Buscar Ordens de uma Tarefa

```sql
-- Buscar todas as ordens vinculadas a uma tarefa
SELECT 
    o.id,
    o.ordem,  -- Campo 'ordem' é o identificador único (TEXT)
    o.texto_breve,  -- Usando texto_breve como descrição
    COUNT(m.id) AS total_mensagens
FROM tasks_ordens to_rel
JOIN ordens o ON o.id = to_rel.ordem_id
LEFT JOIN mensagens m ON m.ref_type = 'ORDEM' AND m.ref_id = o.id
WHERE to_rel.task_id = '<task_id>'
GROUP BY o.id, o.ordem, o.texto_breve
ORDER BY o.ordem;
```

### Buscar Mensagens de uma Nota

```sql
-- Buscar todas as mensagens vinculadas a uma nota
SELECT 
    m.id,
    m.conteudo,
    m.usuario_nome,
    m.created_at,
    m.ref_label
FROM mensagens m
WHERE m.ref_type = 'NOTA' 
  AND m.ref_id = '<nota_sap_id>'
  AND m.deleted_at IS NULL
ORDER BY m.created_at ASC;
```

### Buscar Mensagens de uma Ordem

```sql
-- Buscar todas as mensagens vinculadas a uma ordem
SELECT 
    m.id,
    m.conteudo,
    m.usuario_nome,
    m.created_at,
    m.ref_label
FROM mensagens m
WHERE m.ref_type = 'ORDEM' 
  AND m.ref_id = '<ordem_id>'
  AND m.deleted_at IS NULL
ORDER BY m.created_at ASC;
```

### Buscar Mensagens de uma Tarefa por Tipo

```sql
-- Buscar mensagens de uma tarefa, agrupadas por tipo de referência
SELECT 
    m.ref_type,
    m.ref_id,
    m.ref_label,
    COUNT(*) AS quantidade
FROM mensagens m
JOIN grupos_chat gc ON gc.id = m.grupo_id
WHERE gc.tarefa_id = '<task_id>'
  AND m.deleted_at IS NULL
GROUP BY m.ref_type, m.ref_id, m.ref_label
ORDER BY m.ref_type, m.ref_label;
```

## 📤 Payload Flutter → Node.js

### Payload Antigo (compatibilidade)

```json
{
  "mensagem_id": "uuid",
  "grupo_id": "uuid",
  "conteudo": "Texto da mensagem",
  "tipo": "texto",
  "usuario_nome": "João"
}
```

### Payload Novo (com tags)

```json
{
  "mensagem_id": "uuid",
  "grupo_id": "uuid",
  "conteudo": "Texto da mensagem",
  "tipo": "texto",
  "usuario_nome": "João",
  "ref_type": "NOTA",  // ou "ORDEM" ou omitido (default "GERAL")
  "ref_id": "uuid-da-nota",  // ou "uuid-da-ordem" ou omitido
  "ref_label": "NOTA 12345"  // opcional, pode ser gerado no Node
}
```

## 🔄 Processamento Node.js

### Receber e Processar

```javascript
// No endpoint /send-message
const { mensagem_id, grupo_id, conteudo, ref_type, ref_id, ref_label } = req.body;

// Validar ref_type se fornecido
if (ref_type && !['GERAL', 'NOTA', 'ORDEM'].includes(ref_type)) {
  return res.status(400).json({ error: 'ref_type inválido' });
}

// Se ref_type fornecido, ref_id é obrigatório
if (ref_type && ref_type !== 'GERAL' && !ref_id) {
  return res.status(400).json({ error: 'ref_id é obrigatório quando ref_type != GERAL' });
}

// Salvar no Supabase
const mensagemData = {
  grupo_id,
  conteudo,
  // ... outros campos
  ref_type: ref_type || 'GERAL',
  ref_id: ref_id || null,
  ref_label: ref_label || null,
};

// Se ref_label não fornecido, gerar automaticamente
if (ref_type && ref_type !== 'GERAL' && !ref_label) {
  // Buscar nota/ordem para gerar label
  if (ref_type === 'NOTA') {
    const { data: nota, error: notaError } = await supabase
      .from('notas_sap')
      .select('nota')  // Campo 'nota' é o identificador único (VARCHAR(50))
      .eq('id', ref_id)
      .single();
    
    if (notaError) {
      console.error('Erro ao buscar nota:', notaError);
      return res.status(404).json({ error: 'Nota não encontrada' });
    }
    
    mensagemData.ref_label = nota ? `NOTA ${nota.nota}` : null;
  } else if (ref_type === 'ORDEM') {
    const { data: ordem, error: ordemError } = await supabase
      .from('ordens')
      .select('ordem')  // Campo 'ordem' é o identificador único (TEXT)
      .eq('id', ref_id)
      .single();
    
    if (ordemError) {
      console.error('Erro ao buscar ordem:', ordemError);
      return res.status(404).json({ error: 'Ordem não encontrada' });
    }
    
    mensagemData.ref_label = ordem ? `ORDEM ${ordem.ordem}` : null;
  }
}

// Enviar para Telegram com prefixo
let textoTelegram = conteudo;
if (ref_type === 'NOTA' && mensagemData.ref_label) {
  textoTelegram = `📌 ${mensagemData.ref_label}\n\n${conteudo}`;
} else if (ref_type === 'ORDEM' && mensagemData.ref_label) {
  textoTelegram = `🧾 ${mensagemData.ref_label}\n\n${conteudo}`;
} else {
  textoTelegram = `💬 GERAL\n\n${conteudo}`;
}
```

## 📱 Flutter: UI e Lógica

### Modelo de Dados

```dart
class Mensagem {
  // ... campos existentes
  String? refType;  // 'GERAL' | 'NOTA' | 'ORDEM'
  String? refId;     // UUID da nota/ordem
  String? refLabel;  // Label para exibição
}
```

### Widget Seletor de Tag

```dart
Widget _buildTagSelector(String taskId) {
  return DropdownButton<String>(
    value: _selectedRefType ?? 'GERAL',
    items: [
      DropdownMenuItem(value: 'GERAL', child: Text('💬 Geral')),
      DropdownMenuItem(value: 'NOTA', child: Text('📌 Nota')),
      DropdownMenuItem(value: 'ORDEM', child: Text('🧾 Ordem')),
    ],
    onChanged: (value) {
      setState(() {
        _selectedRefType = value;
        _selectedRefId = null;  // Limpar seleção anterior
      });
      
      // Se selecionou NOTA ou ORDEM, carregar opções
      if (value != 'GERAL') {
        _loadRefOptions(taskId, value);
      }
    },
  );
}

Widget _buildRefSelector() {
  if (_selectedRefType == null || _selectedRefType == 'GERAL') {
    return SizedBox.shrink();
  }
  
  return DropdownButton<String>(
    value: _selectedRefId,
    items: _refOptions.map((ref) {
      return DropdownMenuItem(
        value: ref.id,
        child: Text(ref.label),
      );
    }).toList(),
    onChanged: (value) {
      setState(() {
        _selectedRefId = value;
      });
    },
  );
}

Future<void> _loadRefOptions(String taskId, String refType) async {
  if (refType == 'NOTA') {
    // Buscar notas da tarefa
    final response = await _supabase
        .from('tasks_notas_sap')
        .select('nota_sap_id, notas_sap(nota, descricao)')  // Campo 'nota' é o identificador
        .eq('task_id', taskId);
    
    _refOptions = response.map((item) => {
      final nota = item['notas_sap'];
      return RefOption(
        id: item['nota_sap_id'],
        label: 'NOTA ${nota['nota']}',
      );
    }).toList();
  } else if (refType == 'ORDEM') {
    // Buscar ordens da tarefa
    final response = await _supabase
        .from('tasks_ordens')
        .select('ordem_id, ordens(ordem, texto_breve)')  // Campo 'ordem' é o identificador
        .eq('task_id', taskId);
    
    _refOptions = response.map((item) => {
      final ordem = item['ordens'];
      return RefOption(
        id: item['ordem_id'],
        label: 'ORDEM ${ordem['ordem']}',
      );
    }).toList();
  }
}
```

### Enviar Mensagem com Tag

```dart
Future<void> _enviarMensagem() async {
  final texto = _messageController.text.trim();
  if (texto.isEmpty) return;
  
  // Obter task_id do grupo
  final grupo = await _chatService.obterGrupo(widget.grupoId);
  final taskId = grupo?.tarefaId;
  
  // Preparar payload
  final payload = {
    'grupo_id': widget.grupoId,
    'conteudo': texto,
    'tipo': 'texto',
    'usuario_nome': nomeUsuario,
  };
  
  // Adicionar tags se selecionadas
  if (_selectedRefType != null && _selectedRefType != 'GERAL') {
    payload['ref_type'] = _selectedRefType;
    payload['ref_id'] = _selectedRefId;
    if (_selectedRefLabel != null) {
      payload['ref_label'] = _selectedRefLabel;
    }
  }
  
  // Enviar via Node.js
  await _telegramService.sendMessage(payload);
}
```

## 🔄 Telegram → Supabase (Compatibilidade)

Mensagens recebidas do Telegram **não terão tags** (serão tratadas como 'GERAL'):

```javascript
// No processMessage do Node.js
const novaMensagem = {
  grupo_id: taskMapping.grupo_chat_id,
  conteudo: messageText,
  source: 'telegram',
  ref_type: 'GERAL',  // Sempre GERAL para mensagens do Telegram
  ref_id: null,
  ref_label: null,
};
```

## ✅ Checklist de Implementação

- [ ] Executar SQL de migração no Supabase
- [ ] Atualizar modelo `Mensagem` no Flutter
- [ ] Criar widget seletor de tag no Flutter
- [ ] Implementar busca de notas/ordens por tarefa
- [ ] Atualizar `ChatService.enviarMensagem()` para incluir tags
- [ ] Atualizar Node.js `/send-message` para aceitar tags
- [ ] Implementar formatação de mensagem Telegram com prefixo
- [ ] Adicionar filtros na UI do Flutter (por tag)
- [ ] Testar compatibilidade com mensagens antigas
- [ ] Testar compatibilidade com mensagens do Telegram
- [ ] Documentar para usuários

## 🎨 Visualização no Telegram

```
📌 NOTA 12345

Texto da mensagem aqui...

---

🧾 ORDEM 67890

Texto da mensagem aqui...

---

💬 GERAL

Texto da mensagem aqui...
```

## 📊 Diagrama Textual

```
┌─────────────┐
│  MENSAGENS  │
│             │
│ ref_type    │───┐
│ ref_id      │   │
│ ref_label   │   │
└─────────────┘   │
       │           │
       │ grupo_id  │
       ▼           │
┌─────────────┐   │
│ GRUPOS_CHAT │   │
│             │   │
│ tarefa_id   │───┼───┐
└─────────────┘   │   │
       │           │   │
       │           │   │
       ▼           │   │
┌─────────────┐   │   │
│    TASKS    │   │   │
└─────────────┘   │   │
       │           │   │
       ├───────────┘   │
       │               │
       ├─── tasks_notas_sap ───► notas_sap (ref_id quando ref_type='NOTA')
       │
       └─── tasks_ordens ──────► ordens (ref_id quando ref_type='ORDEM')
```

## 🚀 Próximos Passos

1. **Validar schema**: Confirmar que `grupos_chat.tarefa_id` existe
2. **Validar campos**: Confirmar campos `numero` em `notas_sap` e `ordens`
3. **Executar migração**: Rodar SQL de migração
4. **Implementar Flutter**: Widgets e lógica
5. **Implementar Node.js**: Processamento de tags
6. **Testar**: Cenários completos
