# Workflow N8N - Agente Telegram com Validações de Permissão

## 📋 Visão Geral

Este workflow N8N atua como **AGENTE/INSIGHTS/CONSULTAS** para o Telegram, permitindo que executores consultem tarefas, mensagens e dados SAP através de comandos, respeitando as mesmas regras de permissão do Flutter.

## 🔐 Regras de Permissão

Um executor pode ver uma task se **QUALQUER** condição for verdadeira:

1. **Participante direto**: Existe em `tasks_executores(task_id, executor_id)`
2. **Via equipe**: Existe em `tasks_equipes(task_id, equipe_id)` E `equipes_executores(equipe_id, executor_id)`
3. **Por divisão/segmento** (opcional): 
   - `executores.divisao_id = tasks.divisao_id` OU
   - Existe em `executores_segmentos(executor_id, segmento_id)` onde `segmento_id = tasks.segmento_id`

## 📊 Schema Relevante

### Tabelas Principais

- `telegram_identities`: `user_id` → `executores.id`, `telegram_user_id`
- `executores`: `id`, `nome`, `divisao_id`, `segmento_id` (deprecated, usar executores_segmentos)
- `executores_segmentos`: `executor_id`, `segmento_id` (many-to-many)
- `tasks`: `id`, `tarefa`, `status`, `divisao_id`, `segmento_id`, `regional_id`, `data_inicio`, `data_fim`, etc.
- `tasks_executores`: `task_id`, `executor_id`
- `tasks_equipes`: `task_id`, `equipe_id`
- `equipes_executores`: `equipe_id`, `executor_id`
- `grupos_chat`: `id`, `tarefa_id`, `comunidade_id`
- `mensagens`: `id`, `grupo_id`, `usuario_id`, `source`, `conteudo`, `created_at`, `deleted_at`
- `telegram_task_topics`: `task_id`, `grupo_chat_id`, `telegram_chat_id`, `telegram_topic_id`
- `tasks_ordens`: `task_id`, `ordem_id`
- `tasks_notas_sap`: `task_id`, `nota_sap_id`
- `tasks_si`: `task_id`, `si_id`

## 🎯 Comandos Suportados

### Consultas de Tarefas
- `vencendo` - Tarefas vencendo/atrasadas
- `hoje` - Tarefas do dia
- `status ANDA` / `status PROG` / `status CONC` / `status CANC` / `status RPAR`
- `tarefa <texto>` - Buscar tarefas por nome/trecho
- `id <uuid>` - Buscar tarefa por ID

### Consultas SAP
- `ordem 5000...` - Buscar ordem e tarefas vinculadas
- `nota 123...` - Buscar nota SAP e tarefas vinculadas
- `si 000...` - Buscar SI e tarefas vinculadas
- `sap <task_uuid>` - Links SAP de uma tarefa específica

### Consultas de Chat
- `chat <task_uuid>` - Últimas 5 mensagens de uma tarefa

## 🔧 Configuração

### 1. Credenciais Postgres no N8N

1. Acesse **Settings** → **Credentials**
2. Adicione nova credencial **Postgres**
3. Preencha:
   - **Host**: `212.85.0.249`
   - **Port**: `5432`
   - **Database**: `postgres`
   - **User**: `postgres`
   - **Password**: (senha do Supabase)
   - **SSL**: Desabilitado (ou conforme configuração)

### 2. Credenciais Telegram no N8N

1. Adicione credencial **Telegram Trigger**
2. Configure o Bot Token do Telegram

## 📝 Estrutura do Workflow

```
Telegram Trigger
  ↓
Normalize Message
  ↓
Lookup Identity (telegram_identities → executores)
  ↓
Authorize Context (Function - buscar divisao/segmento/equipes)
  ↓
Router (Function - parse comandos)
  ↓
[Switch por comando]
  ├─ vencendo → Query Tasks Due (com filtro permissão)
  ├─ hoje → Query Tasks Today (com filtro permissão)
  ├─ status → Query Tasks By Status (com filtro permissão)
  ├─ tarefa → Query Tasks By Name (com filtro permissão)
  ├─ id → Query Task By ID (com filtro permissão)
  ├─ ordem → Query Ordem (com validação acesso)
  ├─ nota → Query Nota SAP (com validação acesso)
  ├─ si → Query SI (com validação acesso)
  ├─ sap → Query SAP Links (com validação acesso)
  └─ chat → Query Chat Messages (com validação acesso)
  ↓
Format Response
  ↓
Reply to Telegram
```

## 🛡️ Validações de Segurança

1. **SQL Injection**: Todos os parâmetros são sanitizados
2. **UUID Validation**: Regex para validar UUIDs
3. **Status Enum**: Apenas valores permitidos (ANDA, PROG, CONC, CANC, RPAR)
4. **Números**: Apenas para ordem/nota/si (validação de formato)

## 📤 Formato de Respostas

### Listagens (máximo 10 itens)
```
📋 Tarefas encontradas: 3

1. [ANDA] Tarefa: Instalação de equipamentos
   Local: São Paulo | Executor: João Silva
   Início: 25/01/2026 | Fim: 30/01/2026
   ID: 550e8400-e29b-41d4-a716-446655440000
   TG: topic_id 123

2. [PROG] Tarefa: Manutenção preventiva
   ...
```

### Chat Messages
```
💬 Últimas mensagens (Tarefa: Instalação):

[25/01 14:30] João Silva (app):
  Equipamento instalado com sucesso

[25/01 14:25] Maria Santos (telegram):
  Aguardando liberação do cliente
```

### SAP Links
```
🔗 Links SAP (Tarefa: Instalação):

📄 Ordem: 5000123
📋 Nota: 123456
📑 SI: 000789

TG: topic_id 123
```

## 🧪 Testes

Execute os seguintes comandos no Telegram:

1. `vencendo` - Deve retornar apenas tarefas acessíveis
2. `status PROG` - Deve retornar apenas tarefas PROG acessíveis
3. `sap <uuid_de_tarefa_acessivel>` - Deve retornar links SAP
4. `sap <uuid_de_tarefa_inacessivel>` - Deve retornar erro de permissão
5. `chat <uuid_de_tarefa_acessivel>` - Deve retornar mensagens
6. `ordem 5000123` - Deve retornar ordem se vinculada a tarefa acessível

## ⚠️ Notas Importantes

- Timezone: `America/Sao_Paulo`
- Respostas curtas e operacionais
- IDs sempre incluídos para referência
- Datas no formato pt-BR (dd/MM/yyyy)
- Limite de 10 itens em listagens
- Limite de 5 mensagens em chat
