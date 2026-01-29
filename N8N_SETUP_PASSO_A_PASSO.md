# Setup N8N Workflow - Passo a Passo

## 📋 Pré-requisitos

1. N8N instalado e acessível em `http://212.85.0.249:5678`
2. Credenciais do Postgres (Supabase)
3. Bot Token do Telegram

## 🔧 Passo 1: Configurar Credenciais

### 1.1 Credenciais Postgres

1. No N8N, vá em **Settings** → **Credentials**
2. Clique em **Add Credential**
3. Selecione **Postgres**
4. Preencha:
   - **Name**: `Supabase Postgres`
   - **Host**: `212.85.0.249`
   - **Database**: `postgres`
   - **User**: `postgres`
   - **Password**: (senha do Supabase)
   - **Port**: `5432`
   - **SSL**: Desabilitado

### 1.2 Credenciais Telegram

1. Adicione credencial **Telegram Trigger**
2. Preencha o **Bot Token** do Telegram

---

## 🏗️ Passo 2: Criar Nodes

### Node 1: Telegram Trigger

- **Type**: Telegram Trigger
- **Updates**: `message`
- **Credential**: Telegram Bot Token

### Node 2: Normalize Message

- **Type**: Code
- **Code**:
```javascript
const message = $input.item.json.message;
const text = message?.text || message?.caption || '';
const from = message?.from || {};

return {
  json: {
    telegram_user_id: from.id,
    telegram_username: from.username,
    telegram_first_name: from.first_name,
    chat_id: message.chat.id,
    message_id: message.message_id,
    text: text.trim().toLowerCase(),
    original_text: text.trim()
  }
};
```

### Node 3: Lookup Identity

- **Type**: Postgres
- **Operation**: Execute Query
- **Query**: (ver `N8N_QUERIES_SQL.md` - Query 1)
- **Query Parameters**: `={{ [$json.telegram_user_id] }}`
- **Credential**: Supabase Postgres

### Node 4: Check Identity (IF)

- **Type**: IF
- **Condition**: `executor_id` is not empty

### Node 5: Authorize Context

- **Type**: Code
- **Code**:
```javascript
const executorId = $input.item.json.executor_id;
const executorNome = $input.item.json.executor_nome;
const divisaoId = $input.item.json.divisao_id;
const segmentoId = $input.item.json.segmento_id;

return {
  json: {
    executor_id: executorId,
    executor_nome: executorNome,
    divisao_id: divisaoId,
    segmento_id: segmentoId,
    context_loaded: true
  }
};
```

### Node 6: Router

- **Type**: Code
- **Code**: (ver seção Router no workflow)

### Node 7: Switch Intent

- **Type**: Switch
- **Mode**: Rules
- **Rules**: 
  - `vencendo` → output 0
  - `hoje` → output 1
  - `status` → output 2
  - `tarefa` → output 3
  - `id` → output 4
  - `ordem` → output 5
  - `nota` → output 6
  - `si` → output 7
  - `sap` → output 8
  - `chat` → output 9
  - default → output 10

### Nodes 8-18: Queries Postgres

Para cada intent, criar node Postgres com a query correspondente de `N8N_QUERIES_SQL.md`

### Nodes 19-22: Format Responses

Criar nodes Code para formatar respostas (ver exemplos abaixo)

### Node Final: Reply to Telegram

- **Type**: Telegram
- **Operation**: Send Message
- **Chat ID**: `={{ $('Normalize Message').item.json.chat_id }}`
- **Text**: `={{ $json.response }}`

---

## 📝 Exemplos de Code Nodes

### Extract Status

```javascript
const originalText = $input.item.json.original_text || '';
const match = originalText.match(/^status\s+(anda|prog|conc|canc|rpar)$/i);
const statusCodigo = match ? match[1].toUpperCase() : null;

// Validar
const allowed = ['ANDA', 'PROG', 'CONC', 'CANC', 'RPAR'];
if (statusCodigo && !allowed.includes(statusCodigo)) {
  throw new Error('Status inválido');
}

return {
  json: {
    ...$input.item.json,
    status_codigo: statusCodigo
  }
};
```

### Extract Task ID (para sap/chat/id)

```javascript
const originalText = $input.item.json.original_text || '';
const match = originalText.match(/^(sap|chat|id)\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i);
const taskId = match ? match[2] : null;

if (!taskId || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(taskId)) {
  throw new Error('UUID inválido');
}

return {
  json: {
    ...$input.item.json,
    task_id: taskId
  }
};
```

### Format Tasks Response

```javascript
const items = $input.all();

if (items.length === 0) {
  return { json: { response: 'Nenhuma tarefa encontrada.' } };
}

const formatDate = (dateStr) => {
  if (!dateStr) return 'N/A';
  const date = new Date(dateStr);
  return date.toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' });
};

let response = `📋 Tarefas encontradas: ${items.length}\n\n`;

items.forEach((item, index) => {
  const t = item.json;
  const statusEmoji = {
    'ANDA': '🟡', 'PROG': '🔵', 'CONC': '✅', 'CANC': '❌', 'RPAR': '🔄'
  }[t.status_codigo] || '⚪';
  
  response += `${index + 1}. ${statusEmoji} [${t.status_codigo}] ${t.tarefa}\n`;
  response += `   Local: ${t.locais_nomes} | Executor: ${t.executores_nomes}\n`;
  response += `   Início: ${formatDate(t.data_inicio)} | Fim: ${formatDate(t.data_fim)}\n`;
  response += `   ID: ${t.id}\n`;
  if (t.telegram_topic_id) {
    response += `   TG: topic_id ${t.telegram_topic_id}\n`;
  }
  response += '\n';
});

return { json: { response: response.trim() } };
```

### Format Chat Response

```javascript
const items = $input.all();

if (items.length === 0) {
  return { json: { response: 'Nenhuma mensagem encontrada.' } };
}

const formatDateTime = (dateStr) => {
  if (!dateStr) return 'N/A';
  const date = new Date(dateStr);
  return date.toLocaleString('pt-BR', { 
    timeZone: 'America/Sao_Paulo',
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  });
};

let response = `💬 Últimas mensagens (Tarefa: ${items[0]?.json?.tarefa_nome || 'N/A'}):\n\n`;

items.reverse().forEach((item) => {
  const m = item.json;
  const sourceEmoji = m.source === 'telegram' ? '📱' : '📲';
  response += `[${formatDateTime(m.created_at)}] ${m.autor_nome} ${sourceEmoji}:\n`;
  response += `  ${m.conteudo}\n\n`;
});

return { json: { response: response.trim() } };
```

---

## 🔗 Conectar Nodes

1. **Telegram Trigger** → **Normalize Message**
2. **Normalize Message** → **Lookup Identity**
3. **Lookup Identity** → **Check Identity**
4. **Check Identity** (true) → **Authorize Context**
5. **Check Identity** (false) → **Format No Identity**
6. **Authorize Context** → **Router**
7. **Router** → **Switch Intent**
8. Cada saída do Switch → Query correspondente → Format → **Reply to Telegram**

---

## ✅ Testes

Após configurar, teste com:

1. `/vencendo` - Deve retornar tarefas vencidas acessíveis
2. `/status PROG` - Deve retornar tarefas PROG acessíveis
3. `/tarefa instalação` - Deve buscar tarefas com "instalação"
4. `/sap <uuid>` - Deve retornar links SAP (se tiver acesso)
5. `/chat <uuid>` - Deve retornar mensagens (se tiver acesso)
6. `/ordem 5000123` - Deve retornar ordem se vinculada a tarefa acessível

---

## ⚠️ Troubleshooting

### Erro: "Usuário não identificado"
- Verificar se `telegram_identities` tem registro para o `telegram_user_id`
- Verificar se `executores` tem registro ativo

### Erro: "Nenhuma tarefa encontrada"
- Verificar se o executor tem permissão (tasks_executores ou equipes_executores)
- Verificar se há tarefas no período

### Erro: "Você não tem acesso"
- Verificar se a tarefa está em tasks_executores ou tasks_equipes
- Verificar divisão/segmento do executor
