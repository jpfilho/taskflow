# Workflow N8N - Agente Telegram (Versão Atualizada)

## 📋 Resumo das Melhorias

Este documento descreve as melhorias implementadas no workflow N8N para garantir que todas as consultas respeitem as regras de permissão do Flutter.

## 🔐 Regras de Permissão Implementadas

Um executor pode ver uma task se **QUALQUER** condição for verdadeira:

1. **Participante direto**: Existe em `tasks_executores(task_id, executor_id)`
2. **Via equipe**: Existe em `tasks_equipes(task_id, equipe_id)` E `equipes_executores(equipe_id, executor_id)`
3. **Por divisão/segmento**: 
   - `executores.divisao_id = tasks.divisao_id` OU
   - Existe em `executores_segmentos(executor_id, segmento_id)` onde `segmento_id = tasks.segmento_id`

## 🆕 Melhorias Implementadas

### 1. Node "Lookup Equipes" Adicionado

**Antes**: As equipes eram buscadas apenas nas queries individuais (dentro de CTEs).

**Agora**: Um node Postgres dedicado busca todas as equipes do executor antes de processar comandos, permitindo reutilização do contexto.

**Query:**
```sql
SELECT DISTINCT equipe_id
FROM equipes_executores
WHERE executor_id = $1::uuid;
```

### 2. Node "Authorize Context" Melhorado

**Antes**: Apenas retornava dados básicos do executor, sem equipes.

**Agora**: Combina dados do executor (do "Lookup Identity") com equipes (do "Lookup Equipes") em um contexto completo.

**Código:**
```javascript
const executorData = $('Lookup Identity').item.json;
const equipesData = $input.all();

const executorId = executorData.executor_id;
const executorNome = executorData.executor_nome;
const divisaoId = executorData.divisao_id;

const equipesIds = equipesData.map(item => item.json.equipe_id).filter(id => id != null);

return {
  json: {
    executor_id: executorId,
    executor_nome: executorNome,
    divisao_id: divisaoId,
    equipes_ids: equipesIds,
    context_loaded: true
  }
};
```

### 3. Lookup Identity Simplificado

**Antes**: Tentava buscar `segmento_id` (campo deprecated).

**Agora**: Busca apenas `executor_id`, `executor_nome` e `divisao_id`. Os segmentos são verificados via `executores_segmentos` nas queries de permissão (condição 3).

### 4. Todas as Queries com Filtros de Permissão

Todas as queries de tarefas agora incluem o filtro completo de permissão:

```sql
AND (
  -- Condição 1: Participante direto
  EXISTS (
    SELECT 1 FROM tasks_executores te
    WHERE te.task_id = t.id AND te.executor_id = $1::uuid
  )
  -- Condição 2: Via equipe
  OR EXISTS (
    SELECT 1
    FROM tasks_equipes tq
    JOIN equipes_executores ee ON ee.equipe_id = tq.equipe_id
    WHERE tq.task_id = t.id AND ee.executor_id = $1::uuid
  )
  -- Condição 3: Por divisão/segmento
  OR ($2::uuid IS NOT NULL AND t.divisao_id = $2::uuid)
  OR EXISTS (
    SELECT 1
    FROM executores_segmentos es
    WHERE es.executor_id = $1::uuid
      AND es.segmento_id = t.segmento_id
  )
)
```

### 5. Validações de Permissão para SAP e Chat

Antes de consultar dados SAP ou mensagens de chat, o workflow valida se o executor tem acesso à tarefa:

- **Check Task Permission (SAP)**: Valida acesso antes de retornar links SAP
- **Check Task Permission (Chat)**: Valida acesso antes de retornar mensagens

Se não tiver acesso, retorna: "Você não tem acesso a essa tarefa."

### 6. Validações de Acesso para Ordem/Nota/SI

As queries de ordem, nota e SI agora só retornam dados se estiverem vinculados a tarefas acessíveis:

```sql
WITH accessible_tasks AS (
  SELECT DISTINCT t.id as task_id
  FROM tasks t
  WHERE (filtro de permissão completo)
)
SELECT ...
FROM ordens o
JOIN tasks_ordens to_rel ON to_rel.ordem_id = o.id
JOIN accessible_tasks at ON at.task_id = to_rel.task_id
...
```

## 📊 Estrutura do Workflow Atualizada

```
Telegram Trigger
  ↓
Normalize Message
  ↓
Lookup Identity (busca executor_id, nome, divisao_id)
  ↓
Check Identity (IF executor_id existe)
  ├─ SIM → Lookup Equipes (busca equipes do executor)
  │         ↓
  │         Authorize Context (combina executor + equipes)
  │         ↓
  │         Router (parse comandos)
  │         ↓
  │         [Switch por comando]
  │         ├─ vencendo → Query Tasks Due (com filtro permissão)
  │         ├─ hoje → Query Tasks Today (com filtro permissão)
  │         ├─ status → Query Tasks By Status (com filtro permissão)
  │         ├─ tarefa → Query Tasks By Name (com filtro permissão)
  │         ├─ id → Query Task By ID (com filtro permissão)
  │         ├─ ordem → Query Ordem (só tarefas acessíveis)
  │         ├─ nota → Query Nota SAP (só tarefas acessíveis)
  │         ├─ si → Query SI (só tarefas acessíveis)
  │         ├─ sap → Check Permission → Query SAP Links
  │         └─ chat → Check Permission → Query Chat Messages
  │         ↓
  │         Format Response
  │         ↓
  │         Reply to Telegram
  │
  └─ NÃO → Format No Identity → Reply to Telegram
```

## 🔒 Segurança

### Sanitização de Inputs

- **UUIDs**: Validados com regex `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- **Status**: Apenas valores permitidos: `ANDA`, `PROG`, `CONC`, `CANC`, `RPAR`
- **Números**: Apenas dígitos para ordem/nota/si
- **Texto**: Caracteres perigosos removidos (`;`, `'`, `"`, `\`)

### SQL Injection Prevention

Todas as queries usam parâmetros preparados (`$1`, `$2`, etc.) ao invés de concatenação de strings.

## 📝 Comandos Suportados

### Consultas de Tarefas
- `vencendo` - Tarefas vencendo/atrasadas
- `hoje` - Tarefas do dia
- `status ANDA` / `status PROG` / `status CONC` / `status CANC` / `status RPAR`
- `tarefa <texto>` - Buscar tarefas por nome/trecho
- `id <uuid>` - Buscar tarefa por ID

### Consultas SAP
- `ordem 5000...` - Buscar ordem e tarefas vinculadas (só acessíveis)
- `nota 123...` - Buscar nota SAP e tarefas vinculadas (só acessíveis)
- `si 000...` - Buscar SI e tarefas vinculadas (só acessíveis)
- `sap <task_uuid>` - Links SAP de uma tarefa específica (com validação de acesso)

### Consultas de Chat
- `chat <task_uuid>` - Últimas 5 mensagens de uma tarefa (com validação de acesso)

## 🧪 Testes Recomendados

1. **Teste de Permissão Direta**:
   - Executor A participa diretamente da tarefa X
   - Comando: `id <uuid_tarefa_x>`
   - Resultado esperado: Tarefa retornada

2. **Teste de Permissão por Equipe**:
   - Executor B está em equipe Y, que está associada à tarefa Z
   - Comando: `id <uuid_tarefa_z>`
   - Resultado esperado: Tarefa retornada

3. **Teste de Permissão por Divisão**:
   - Executor C tem divisao_id = D, tarefa W tem divisao_id = D
   - Comando: `id <uuid_tarefa_w>`
   - Resultado esperado: Tarefa retornada

4. **Teste de Permissão por Segmento**:
   - Executor D tem segmento S via executores_segmentos, tarefa V tem segmento_id = S
   - Comando: `id <uuid_tarefa_v>`
   - Resultado esperado: Tarefa retornada

5. **Teste de Negação de Acesso**:
   - Executor E não tem nenhuma relação com tarefa T
   - Comando: `sap <uuid_tarefa_t>`
   - Resultado esperado: "Você não tem acesso a essa tarefa."

6. **Teste de Ordem sem Vínculo Acessível**:
   - Ordem 5000 está vinculada apenas a tarefas inacessíveis para executor F
   - Comando: `ordem 5000`
   - Resultado esperado: "Ordem/Nota/SI não encontrada ou sem vínculo com tarefas acessíveis para você."

## 📊 Índices Recomendados

Para melhorar performance, execute estes índices no Supabase:

```sql
-- Índices para validação de permissão
CREATE INDEX IF NOT EXISTS idx_tasks_executores_task_executor 
  ON tasks_executores(task_id, executor_id);

CREATE INDEX IF NOT EXISTS idx_equipes_executores_equipe_executor 
  ON equipes_executores(equipe_id, executor_id);

CREATE INDEX IF NOT EXISTS idx_tasks_equipes_task_equipe 
  ON tasks_equipes(task_id, equipe_id);

CREATE INDEX IF NOT EXISTS idx_executores_segmentos_executor_segmento 
  ON executores_segmentos(executor_id, segmento_id);

-- Índices para consultas de chat
CREATE INDEX IF NOT EXISTS idx_grupos_chat_tarefa_id 
  ON grupos_chat(tarefa_id);

CREATE INDEX IF NOT EXISTS idx_mensagens_grupo_created 
  ON mensagens(grupo_id, created_at DESC) 
  WHERE deleted_at IS NULL;

-- Índices para consultas SAP
CREATE INDEX IF NOT EXISTS idx_tasks_ordens_task_ordem 
  ON tasks_ordens(task_id, ordem_id);

CREATE INDEX IF NOT EXISTS idx_tasks_notas_sap_task_nota 
  ON tasks_notas_sap(task_id, nota_sap_id);

CREATE INDEX IF NOT EXISTS idx_tasks_si_task_si 
  ON tasks_si(task_id, si_id);
```

## 🔧 Como Importar o Workflow

1. Acesse o N8N em `https://api.taskflowv3.com.br/n8n` (ou `http://212.85.0.249:5678` se HTTPS não estiver configurado)
2. Vá em **Workflows** → **Import from File**
3. Selecione o arquivo `n8n_workflow_telegram_agente.json`
4. Configure as credenciais:
   - **Postgres**: `Supabase Postgres` (host: 212.85.0.249, port: 5432)
   - **Telegram**: `Telegram Bot` (com o bot token)
5. **IMPORTANTE**: Configure HTTPS antes de ativar o workflow (veja seção abaixo)
6. Ative o workflow

## 🔐 Configurar HTTPS para Webhooks Telegram

O Telegram **exige HTTPS** para webhooks. Se você receber o erro:
```
Bad Request: bad webhook: An HTTPS URL must be provided for webhook
```

Execute o script de configuração:

```powershell
.\configurar_n8n_https.ps1
```

Este script irá:
1. ✅ Verificar se o certificado SSL existe
2. ✅ Configurar Nginx para expor N8N via HTTPS
3. ✅ Atualizar container do N8N com URL HTTPS
4. ✅ Testar a configuração

Após executar, o N8N estará acessível em:
- **URL**: `https://api.taskflowv3.com.br/n8n`
- **Webhook URL**: `https://api.taskflowv3.com.br/n8n/`

**Nota**: Se você ainda não configurou HTTPS no servidor, execute primeiro:
```bash
# No servidor
bash configurar_https_taskflow.sh
```

## ⚠️ Notas Importantes

- **Timezone**: Todas as datas usam `America/Sao_Paulo`
- **Limites**: 
  - Listagens: máximo 10 itens
  - Chat: máximo 5 mensagens
- **Formato de Respostas**: Curto e operacional, com IDs e datas em pt-BR
- **telegram_task_topics**: Incluído nas respostas quando disponível (formato: `TG: topic_id <id>`)

## 📚 Arquivos Relacionados

- `n8n_workflow_telegram_agente.json` - Workflow completo para importar
- `N8N_QUERIES_SQL.md` - Todas as queries SQL documentadas
- `N8N_SETUP_PASSO_A_PASSO.md` - Guia de configuração passo a passo
- `N8N_WORKFLOW_TELEGRAM_AGENTE.md` - Documentação original do workflow
