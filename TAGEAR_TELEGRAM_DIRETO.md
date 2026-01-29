# Taggear Mensagens Diretamente no Telegram

## 🎯 Como Funciona

Agora é possível taggear mensagens diretamente no Telegram usando comandos ou hashtags!

## 📱 Formatos Suportados

### 1. Comandos (no início da mensagem)

```
/nota 12345 Verifiquei a nota
/ordem 67890 Ordem executada
```

**Variações:**
- `/nota 12345` ou `/n 12345`
- `/ordem 67890` ou `/o 67890`

### 2. Hashtags (em qualquer lugar do texto)

```
Verifiquei a nota #nota12345
Ordem executada #ordem67890
```

**Variações:**
- `#nota12345` ou `#n12345`
- `#ordem67890` ou `#o67890`

### 3. Formato @ (em qualquer lugar do texto)

```
Verifiquei a nota @nota:12345
Ordem executada @ordem:67890
```

**Variações:**
- `@nota:12345` ou `@n:12345`
- `@ordem:67890` ou `@o:67890`

## 🔄 Processamento

### Fluxo Completo

```
Usuário envia no Telegram:
  "/nota 12345 Verifiquei a nota"
  
Node.js processMessage():
  ├─ Detecta comando: /nota 12345
  ├─ Extrai número: 12345
  ├─ Remove comando do texto: "Verifiquei a nota"
  ├─ Busca nota na tarefa atual
  │   └─ tasks_notas_sap → notas_sap
  ├─ Se encontrada:
  │   ├─ ref_type = 'NOTA'
  │   ├─ ref_id = UUID da nota
  │   └─ ref_label = 'NOTA 12345'
  └─ Salva no Supabase com tags
      └─ Flutter recebe com badge "NOTA 12345"
```

## 📝 Exemplos Práticos

### Exemplo 1: Comando no Início

**Telegram:**
```
/nota 11469911 MT Instalar defensas
```

**Resultado:**
- Tag: `NOTA 11469911`
- Conteúdo: `MT Instalar defensas`
- Badge aparece no Flutter: `NOTA 11469911`

### Exemplo 2: Hashtag no Meio

**Telegram:**
```
Verifiquei tudo #nota11469911 está correto
```

**Resultado:**
- Tag: `NOTA 11469911`
- Conteúdo: `Verifiquei tudo está correto`
- Badge aparece no Flutter: `NOTA 11469911`

### Exemplo 3: Ordem com Comando

**Telegram:**
```
/ordem 67890 Executada com sucesso
```

**Resultado:**
- Tag: `ORDEM 67890`
- Conteúdo: `Executada com sucesso`
- Badge aparece no Flutter: `ORDEM 67890`

### Exemplo 4: Sem Tag

**Telegram:**
```
Mensagem geral sem tag
```

**Resultado:**
- Tag: `GERAL`
- Conteúdo: `Mensagem geral sem tag`
- Sem badge (ou badge GERAL se configurado)

## ✅ Validações

### Nota/Ordem Deve Existir

- ✅ Busca apenas nas notas/ordens **vinculadas à tarefa atual**
- ✅ Se não encontrar, mostra aviso no Telegram
- ✅ Mensagem é salva como GERAL se nota/ordem não encontrada

### Múltiplas Tags

- ⚠️ Se detectar tanto NOTA quanto ORDEM, prioriza NOTA
- ⚠️ Recomendado usar apenas uma tag por mensagem

### Comandos vs Hashtags

- ✅ Comandos são removidos do texto final
- ✅ Hashtags são removidas do texto final
- ✅ Formato @ também é removido

## 🎨 Interface no Telegram

### Mensagem Enviada

```
Usuário no Telegram:
/nota 12345 Verifiquei a nota
```

### No Flutter Aparece

```
┌─────────────────────────────┐
│ 📌 NOTA 12345              │ ← Badge
│ João Silva                  │
│ Verifiquei a nota           │
│ 10:30                       │
└─────────────────────────────┘
```

## 💻 Implementação Técnica

### Detecção de Tags

```javascript
// Comandos
const notaCommandMatch = conteudo.match(/^\/(?:nota|n)\s+(\d+)/i);
const ordemCommandMatch = conteudo.match(/^\/(?:ordem|o)\s+(\d+)/i);

// Hashtags
const notaHashtagMatch = conteudo.match(/#(?:nota|n)(\d+)/i);
const ordemHashtagMatch = conteudo.match(/#(?:ordem|o)(\d+)/i);

// Formato @
const notaAtMatch = conteudo.match(/@(?:nota|n):(\d+)/i);
const ordemAtMatch = conteudo.match(/@(?:ordem|o):(\d+)/i);
```

### Busca de Nota/Ordem

```javascript
// Buscar nota vinculada à tarefa
const { data: notaRel } = await supabase
  .from('tasks_notas_sap')
  .select('nota_sap_id, notas_sap(id, nota)')
  .eq('task_id', taskMapping.task_id)
  .eq('notas_sap.nota', notaNumero)
  .maybeSingle();
```

### Remoção de Tags do Texto

```javascript
// Remover comando
conteudo = conteudo.replace(/^\/(?:nota|n)\s+\d+\s*/i, '').trim();

// Remover hashtag
conteudo = conteudo.replace(/#(?:nota|n)\d+/i, '').trim();

// Remover @nota:
conteudo = conteudo.replace(/@(?:nota|n):\d+/i, '').trim();
```

## 📋 Casos de Uso

### Caso 1: Comando Simples

**Telegram:**
```
/n 11469911 Verificado
```

**Resultado:**
- Tag: `NOTA 11469911`
- Texto: `Verificado`

### Caso 2: Hashtag no Final

**Telegram:**
```
Tudo verificado #nota11469911
```

**Resultado:**
- Tag: `NOTA 11469911`
- Texto: `Tudo verificado`

### Caso 3: Múltiplas Hashtags (Primeira Vence)

**Telegram:**
```
Verificado #nota11469911 e #ordem67890
```

**Resultado:**
- Tag: `NOTA 11469911` (primeira detectada)
- Texto: `Verificado e #ordem67890` (segunda hashtag permanece)

### Caso 4: Nota Não Encontrada

**Telegram:**
```
/nota 99999 Teste
```

**Resultado:**
- Aviso no Telegram: `⚠️ Nota 99999 não encontrada para esta tarefa.`
- Mensagem salva como GERAL
- Texto: `Teste`

## 🎯 Vantagens

1. ✅ **Rápido:** Taggear direto no Telegram
2. ✅ **Flexível:** Múltiplos formatos (comando, hashtag, @)
3. ✅ **Intuitivo:** Formato familiar
4. ✅ **Automático:** Remove tags do texto final
5. ✅ **Validado:** Verifica se nota/ordem existe na tarefa

## ⚠️ Limitações

1. ⚠️ **Apenas números:** Tags devem ser números (ex: `12345`, não `ABC123`)
2. ⚠️ **Tarefa atual:** Busca apenas notas/ordens da tarefa do tópico atual
3. ⚠️ **Uma tag por vez:** Se detectar múltiplas, usa a primeira

## 📝 Exemplos de Uso

### Uso Recomendado

```
✅ /nota 12345 Verifiquei a nota
✅ Verifiquei #nota12345
✅ @nota:12345 Tudo OK
```

### Uso Não Recomendado

```
❌ /nota ABC123 (deve ser número)
❌ #nota 12345 (sem espaço entre nota e número)
❌ /nota12345 (sem espaço)
```

## ✅ Status

- ✅ **Node.js:** Implementado
- ✅ **Validação:** Nota/Ordem deve existir na tarefa
- ✅ **Remoção:** Tags são removidas do texto final
- ✅ **Feedback:** Aviso no Telegram se não encontrar

**Pronto para usar!** 🚀

## 🧪 Teste

1. Envie no Telegram: `/nota 11469911 Teste`
2. Verifique se aparece badge no Flutter
3. Verifique se texto final é apenas "Teste" (sem comando)
