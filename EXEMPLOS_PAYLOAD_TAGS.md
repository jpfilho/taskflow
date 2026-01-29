# Exemplos de Payload: Tags Nota/Ordem

## 📤 Flutter → Node.js (`/send-message`)

### Payload Antigo (Compatibilidade - Sem Tags)

```json
{
  "mensagem_id": "550e8400-e29b-41d4-a716-446655440000",
  "grupo_id": "660e8400-e29b-41d4-a716-446655440000",
  "conteudo": "Esta é uma mensagem geral",
  "tipo": "texto",
  "usuario_nome": "João Silva",
  "usuario_id": "770e8400-e29b-41d4-a716-446655440000"
}
```

**Comportamento:** Node.js trata como `ref_type = 'GERAL'`, `ref_id = NULL`

### Payload Novo - Mensagem Geral (Explícito)

```json
{
  "mensagem_id": "550e8400-e29b-41d4-a716-446655440000",
  "grupo_id": "660e8400-e29b-41d4-a716-446655440000",
  "conteudo": "Esta é uma mensagem geral",
  "tipo": "texto",
  "usuario_nome": "João Silva",
  "usuario_id": "770e8400-e29b-41d4-a716-446655440000",
  "ref_type": "GERAL"
}
```

**Comportamento:** Node.js salva como `ref_type = 'GERAL'`, `ref_id = NULL`, `ref_label = NULL`

### Payload Novo - Mensagem com Nota

```json
{
  "mensagem_id": "550e8400-e29b-41d4-a716-446655440000",
  "grupo_id": "660e8400-e29b-41d4-a716-446655440000",
  "conteudo": "Verifiquei a nota e está tudo correto",
  "tipo": "texto",
  "usuario_nome": "João Silva",
  "usuario_id": "770e8400-e29b-41d4-a716-446655440000",
  "ref_type": "NOTA",
  "ref_id": "880e8400-e29b-41d4-a716-446655440000",
  "ref_label": "NOTA 12345"
}
```

**Comportamento:** 
- Node.js salva com `ref_type = 'NOTA'`, `ref_id = UUID da nota`
- Se `ref_label` não fornecido, Node.js busca `notas_sap.nota` e gera automaticamente
- Mensagem no Telegram: `📌 NOTA 12345\n\nVerifiquei a nota e está tudo correto`

### Payload Novo - Mensagem com Ordem

```json
{
  "mensagem_id": "550e8400-e29b-41d4-a716-446655440000",
  "grupo_id": "660e8400-e29b-41d4-a716-446655440000",
  "conteudo": "Ordem executada com sucesso",
  "tipo": "texto",
  "usuario_nome": "João Silva",
  "usuario_id": "770e8400-e29b-41d4-a716-446655440000",
  "ref_type": "ORDEM",
  "ref_id": "990e8400-e29b-41d4-a716-446655440000",
  "ref_label": "ORDEM 67890"
}
```

**Comportamento:**
- Node.js salva com `ref_type = 'ORDEM'`, `ref_id = UUID da ordem`
- Se `ref_label` não fornecido, Node.js busca `ordens.ordem` e gera automaticamente
- Mensagem no Telegram: `🧾 ORDEM 67890\n\nOrdem executada com sucesso`

### Payload Novo - Mensagem com Anexo e Nota

```json
{
  "mensagem_id": "550e8400-e29b-41d4-a716-446655440000",
  "grupo_id": "660e8400-e29b-41d4-a716-446655440000",
  "conteudo": "Foto da nota",
  "tipo": "imagem",
  "arquivo_url": "https://supabase.co/storage/v1/object/public/anexos/...",
  "usuario_nome": "João Silva",
  "usuario_id": "770e8400-e29b-41d4-a716-446655440000",
  "ref_type": "NOTA",
  "ref_id": "880e8400-e29b-41d4-a716-446655440000",
  "ref_label": "NOTA 12345"
}
```

**Comportamento:** Mesmo que mensagem de texto, mas com anexo

## 📥 Telegram → Supabase (via Node.js `processMessage`)

### Mensagem Recebida do Telegram (Sempre GERAL)

```javascript
// Update recebido do Telegram
{
  "message": {
    "message_id": 123,
    "chat": {
      "id": -1001234567890,
      "type": "supergroup"
    },
    "message_thread_id": 19,
    "text": "Mensagem enviada direto do Telegram"
  }
}
```

**Processamento no Node.js:**
```javascript
const novaMensagem = {
  grupo_id: taskMapping.grupo_chat_id,
  conteudo: messageText,
  source: 'telegram',
  ref_type: 'GERAL',  // Sempre GERAL para mensagens do Telegram
  ref_id: null,
  ref_label: null,
};
```

**Resultado no Supabase:**
- `ref_type = 'GERAL'`
- `ref_id = NULL`
- `ref_label = NULL`
- `source = 'telegram'`

## 🔄 Exemplos de Resposta Node.js

### Sucesso - Mensagem Geral

```json
{
  "ok": true,
  "sent": true,
  "sentCount": 1,
  "mensagem_id": "550e8400-e29b-41d4-a716-446655440000",
  "ref_type": "GERAL"
}
```

### Sucesso - Mensagem com Nota

```json
{
  "ok": true,
  "sent": true,
  "sentCount": 1,
  "mensagem_id": "550e8400-e29b-41d4-a716-446655440000",
  "ref_type": "NOTA",
  "ref_id": "880e8400-e29b-41d4-a716-446655440000",
  "ref_label": "NOTA 12345"
}
```

### Erro - ref_id Inválido

```json
{
  "ok": false,
  "error": "ref_id não encontrado",
  "details": "Nota com ID 880e8400-e29b-41d4-a716-446655440000 não existe"
}
```

### Erro - ref_type Inválido

```json
{
  "ok": false,
  "error": "ref_type inválido",
  "details": "ref_type deve ser 'GERAL', 'NOTA' ou 'ORDEM'"
}
```

## 📱 Exemplos Flutter (Dart)

### Enviar Mensagem Geral

```dart
final payload = {
  'grupo_id': grupoId,
  'conteudo': texto,
  'tipo': 'texto',
  'usuario_nome': nomeUsuario,
  // ref_type omitido = GERAL (compatibilidade)
};

await _telegramService.sendMessage(payload);
```

### Enviar Mensagem com Nota

```dart
final payload = {
  'grupo_id': grupoId,
  'conteudo': texto,
  'tipo': 'texto',
  'usuario_nome': nomeUsuario,
  'ref_type': 'NOTA',
  'ref_id': notaId,
  'ref_label': 'NOTA $notaNumero',  // Opcional
};

await _telegramService.sendMessage(payload);
```

### Enviar Mensagem com Ordem

```dart
final payload = {
  'grupo_id': grupoId,
  'conteudo': texto,
  'tipo': 'texto',
  'usuario_nome': nomeUsuario,
  'ref_type': 'ORDEM',
  'ref_id': ordemId,
  'ref_label': 'ORDEM $ordemNumero',  // Opcional
};

await _telegramService.sendMessage(payload);
```

## 🔍 Exemplos de Queries Supabase

### Buscar Notas de uma Tarefa (Flutter)

```dart
final response = await _supabase
    .from('tasks_notas_sap')
    .select('''
      nota_sap_id,
      notas_sap (
        id,
        nota,
        descricao
      )
    ''')
    .eq('task_id', taskId);

final notas = response.map((item) {
  final nota = item['notas_sap'] as Map<String, dynamic>;
  return {
    'id': nota['id'],
    'nota': nota['nota'],  // Campo 'nota' é o identificador
    'label': 'NOTA ${nota['nota']}',
  };
}).toList();
```

### Buscar Ordens de uma Tarefa (Flutter)

```dart
final response = await _supabase
    .from('tasks_ordens')
    .select('''
      ordem_id,
      ordens (
        id,
        ordem,
        texto_breve
      )
    ''')
    .eq('task_id', taskId);

final ordens = response.map((item) {
  final ordem = item['ordens'] as Map<String, dynamic>;
  return {
    'id': ordem['id'],
    'ordem': ordem['ordem'],  // Campo 'ordem' é o identificador
    'label': 'ORDEM ${ordem['ordem']}',
  };
}).toList();
```

### Filtrar Mensagens por Tag (Flutter)

```dart
// Buscar apenas mensagens gerais
final mensagensGerais = await _supabase
    .from('mensagens')
    .select('*')
    .eq('grupo_id', grupoId)
    .eq('ref_type', 'GERAL')
    .isFilter('deleted_at', null)
    .order('created_at');

// Buscar apenas mensagens de uma nota
final mensagensNota = await _supabase
    .from('mensagens')
    .select('*')
    .eq('grupo_id', grupoId)
    .eq('ref_type', 'NOTA')
    .eq('ref_id', notaId)
    .isFilter('deleted_at', null)
    .order('created_at');

// Buscar apenas mensagens de uma ordem
final mensagensOrdem = await _supabase
    .from('mensagens')
    .select('*')
    .eq('grupo_id', grupoId)
    .eq('ref_type', 'ORDEM')
    .eq('ref_id', ordemId)
    .isFilter('deleted_at', null)
    .order('created_at');
```

## 🎨 Exemplos de Formatação Telegram

### Mensagem Geral

```
💬 GERAL

Esta é uma mensagem geral do chat
```

### Mensagem com Nota

```
📌 NOTA 12345

Verifiquei a nota e está tudo correto. 
Todos os itens foram conferidos.
```

### Mensagem com Ordem

```
🧾 ORDEM 67890

Ordem executada com sucesso.
Tempo total: 2h30min
```

### Mensagem com Anexo e Nota

```
📌 NOTA 12345

[Imagem anexada]
Foto da nota para conferência
```

## ✅ Validações Node.js

### Validação de Payload

```javascript
// Validar ref_type
if (ref_type && !['GERAL', 'NOTA', 'ORDEM'].includes(ref_type)) {
  return res.status(400).json({ 
    error: 'ref_type inválido',
    details: 'ref_type deve ser GERAL, NOTA ou ORDEM'
  });
}

// Se ref_type != GERAL, ref_id é obrigatório
if (ref_type && ref_type !== 'GERAL' && !ref_id) {
  return res.status(400).json({ 
    error: 'ref_id obrigatório',
    details: 'ref_id é obrigatório quando ref_type != GERAL'
  });
}

// Validar se ref_id existe (se fornecido)
if (ref_type === 'NOTA' && ref_id) {
  const { data: nota, error: notaError } = await supabase
    .from('notas_sap')
    .select('id, nota')  // Buscar também 'nota' para gerar label se necessário
    .eq('id', ref_id)
    .single();
  
  if (notaError || !nota) {
    return res.status(404).json({ 
      error: 'Nota não encontrada',
      details: `Nota com ID ${ref_id} não existe`
    });
  }
  
  // Se ref_label não fornecido, gerar automaticamente
  if (!ref_label && nota.nota) {
    mensagemData.ref_label = `NOTA ${nota.nota}`;
  }
}

if (ref_type === 'ORDEM' && ref_id) {
  const { data: ordem, error: ordemError } = await supabase
    .from('ordens')
    .select('id, ordem')  // Buscar também 'ordem' para gerar label se necessário
    .eq('id', ref_id)
    .single();
  
  if (ordemError || !ordem) {
    return res.status(404).json({ 
      error: 'Ordem não encontrada',
      details: `Ordem com ID ${ref_id} não existe`
    });
  }
  
  // Se ref_label não fornecido, gerar automaticamente
  if (!ref_label && ordem.ordem) {
    mensagemData.ref_label = `ORDEM ${ordem.ordem}`;
  }
}
```
