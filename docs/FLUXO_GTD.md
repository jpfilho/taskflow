# Fluxo detalhado do módulo GTD (Getting Things Done)

Este documento descreve como funciona o fluxo completo do método GTD implantado no TaskFlow: desde a entrada no módulo até a sincronização com o Supabase.

---

## 1. Visão geral da arquitetura

O módulo GTD segue uma estrutura em camadas:

```
┌─────────────────────────────────────────────────────────────────┐
│  APRESENTAÇÃO (presentation/)                                     │
│  GtdHomePage → Tabs (Capturar, Processar, Agora, Projetos, etc.) │
└───────────────────────────────┬───────────────────────────────────┘
                                │
┌───────────────────────────────▼───────────────────────────────────┐
│  DOMÍNIO (domain/)                                                 │
│  GtdSession (userId, canAccessGtd) + Use Cases (Inbox, Actions...)  │
└───────────────────────────────┬───────────────────────────────────┘
                                │
┌───────────────────────────────▼───────────────────────────────────┐
│  DADOS (data/)                                                     │
│  Local: GtdLocalStorage (SQLite) + Sync Queue                     │
│  Remoto: GtdRemoteRepository (Supabase)                           │
│  Orquestração: GtdSyncService (push + pull)                       │
└───────────────────────────────────────────────────────────────────┘
```

- **Usuário**: vem da tabela `usuarios` via `AuthServiceSimples` (não Supabase Auth). O identificador usado em todo o GTD é `GtdSession.currentUserId` (id ou email do usuário logado).
- **Isolamento**: todas as operações locais e remotas são filtradas por `user_id`; cada usuário só vê e altera os próprios dados.

---

## 2. Entrada no módulo GTD

### 2.1 Acesso pelo menu

1. No **main.dart**, o sidebar tem um item "GTD" (índice 25), exibido apenas se `GtdSession.canAccessGtd` for true (por padrão, todo usuário autenticado).
2. Ao tocar em "GTD", o `_sidebarSelectedIndex` vira 25 e `_getViewBySidebarIndex()` retorna `GtdHomePage()`.
3. Antes de mostrar a página, o main verifica `GtdSession.canAccessGtd`; se false, mostra placeholder em vez do GTD.

### 2.2 Inicialização da GtdHomePage

1. **initState()** da `GtdHomePage` chama `_initSync()`.
2. **GtdSession.currentUserId** é obtido: `AuthServiceSimples().currentUser` → `user.id ?? user.email` (nunca null se usuário logado).
3. **GtdSyncService.instance().initialize(userId)**:
   - Inicializa `ConnectivityService`.
   - Se já existir timer de sync (reentrada na página), apenas dispara um `sync(userId)` e retorna (idempotente).
   - Caso contrário:
     - Guarda `_initializedUserId = userId`.
     - Inscreve no `connectionStream` do ConnectivityService: quando a conexão voltar, chama `sync(_initializedUserId)`.
     - Executa um `sync(userId)` imediato.
     - Inicia um **Timer.periodic** de 5 minutos que chama `sync(_initializedUserId)` enquanto houver conexão e não estiver sincronizando.

Assim, ao abrir o GTD, o sync é inicializado uma vez e depois roda ao conectar e a cada 5 minutos.

---

## 3. Fluxo de captura (aba “Capturar”)

É o fluxo principal de “escrever e salvar” no inbox.

### 3.1 UI (GtdCaptureTab)

1. O usuário digita no campo multilinha (“O que está na sua cabeça?”).
2. Pode salvar por:
   - Botão **Salvar**, ou
   - **Enter** (atalho via `Focus.onKeyEvent`: Enter sem Shift chama `_save()`).
3. **\_save()**:
   - Lê o texto, faz `trim()`; se vazio, retorna.
   - Chama `_inboxUseCase.capture(text)` (async).
   - Em sucesso: limpa o campo, chama `_load()` para atualizar a lista e mostra SnackBar “Salvo na caixa de entrada.”
   - Em erro: mostra SnackBar com a mensagem do erro (e em debug imprime no console). O texto **não** é apagado.

### 3.2 Caso de uso: GtdInboxUseCase.capture(content)

1. **userId**: `_userId = GtdSession.currentUserId`. Se null, lança `StateError('Usuário não autenticado')`.
2. **Cria o item**: `GtdInboxItem` com `id = uuid.v4()`, `userId`, `content`, `processedAt = null`, `createdAt` e `updatedAt` em UTC.
3. **Persistência local**:
   - **insertInbox(item)**: insere na tabela `gtd_inbox` do SQLite (GtdLocalStorage). O banco é aberto na primeira vez (web: factory Wasm + in-memory; desktop/mobile: factory FFI + arquivo `gtd_local.db`).
   - **enqueueSync(...)**: insere um registro na tabela **gtd_sync_queue** com:
     - `entity = 'gtd_inbox'`
     - `entity_id = item.id`
     - `op = 'upsert'`
     - `payload_json = item.toJson()` (JSON do item para enviar ao Supabase depois)
     - `created_at`, `next_retry_at = now`, `tries = 0`
4. **Sync em background**: chama `_sync.sync(userId)` (fire-and-forget). Não espera o resultado; a UI já retornou “salvo”.

Resumo: **sempre escreve primeiro no SQLite e na fila; o envio ao Supabase é assíncrono e pode acontecer logo em seguida ou quando a rede voltar.**

---

## 4. Fila de sincronização (sync_queue) e push

### 4.1 Estrutura da sync_queue (local)

Cada linha representa uma operação pendente de enviar ao Supabase:

| Campo          | Uso                                                                 |
|----------------|---------------------------------------------------------------------|
| id             | PK (auto).                                                          |
| entity         | Nome da entidade: `gtd_inbox`, `gtd_actions`, `gtd_contexts`, etc.  |
| entity_id      | UUID do registro (ex.: id do item do inbox).                        |
| op             | `upsert` ou `delete`.                                               |
| payload_json   | JSON do objeto (para upsert); no delete não é usado no remoto.     |
| created_at     | Quando foi enfileirado.                                             |
| next_retry_at  | Próximo momento em que pode ser tentado (respeita backoff).         |
| tries          | Quantidade de tentativas já feitas.                                 |
| last_error     | Última mensagem de erro (opcional).                                 |

### 4.2 Quando o sync roda (GtdSyncService.sync)

O **sync** é acionado:

- Ao abrir o GTD (`initialize` faz um sync imediato).
- Quando o ConnectivityService indica que há conexão de novo.
- A cada 5 minutos pelo timer (se estiver conectado e não estiver sincronizando).

Condições para executar: `_connectivity.isConnected == true` e `_isSyncing == false`.

### 4.3 Push: enviar a fila para o Supabase

1. **getPendingSyncItems()**: no SQLite, busca na `gtd_sync_queue` onde `next_retry_at <= now`, ordenado por `next_retry_at`.
2. Para cada item:
   - Decodifica `payload_json` para `Map<String, dynamic>`.
   - Se **op == 'delete'**: chama o método remoto de delete da entidade (ex.: `deleteContext`, `deleteAction`) com `entityId` e `userId`.
   - Se **op == 'upsert'**: chama o método remoto de upsert da entidade (ex.: `upsertInbox`, `upsertAction`) passando o payload convertido no modelo (ex.: `GtdInboxItem.fromJson(payload)`).
3. Em **sucesso**: remove o item da sync_queue (`deleteSyncItem(id)`).
4. Em **erro**: aplica **backoff exponencial**:
   - `tries = item.tries + 1`
   - `backoffMs = min(baseBackoffMs * 2^tries, maxBackoffMs)` (ex.: 2s, 4s, 8s… até 5 min)
   - `next_retry_at = now + backoffMs`
   - Atualiza o registro na sync_queue com `next_retry_at`, `tries` e `last_error`.

Assim, nenhum dado é perdido: se o servidor falhar, o item continua na fila e será tentado de novo mais tarde.

---

## 5. Pull incremental (atualizar local a partir do Supabase)

Depois do push, o **GtdSyncService** executa o **pull incremental**:

1. **Âncora de tempo**: `after = _lastSyncAt ?? DateTime(1970)`. Na primeira vez usa época antiga para trazer tudo que tiver `updated_at` preenchido.
2. Para cada entidade (contexts, projects, inbox, actions), chama o repositório remoto com filtro **user_id** e **updated_at > after** (ex.: `getContextsUpdatedAfter(userId, after)`).
3. No Supabase as queries são do tipo: `.eq('user_id', userId).gt('updated_at', iso).order('updated_at')`.
4. Cada registro retornado é gravado no SQLite local com **upsert** (insert ou replace por id), garantindo **last-write-wins** por `updated_at`: o que estiver mais recente no servidor sobrescreve o local.

Ordem usada no pull: contexts e projects antes de actions, para respeitar FKs (ex.: action com project_id). Weekly reviews e reference não entram no pull incremental atual (só push).

---

## 6. Fluxo de processar inbox (aba “Processar”)

Objetivo: decidir o que fazer com cada item do inbox (ação ou não, e em qual lista).

### 6.1 Carregamento

1. **\_load()**:
   - Busca itens **não processados**: `_inboxUseCase.getInboxItems(unprocessedOnly: true)` → lê no **local** (`getInboxItems(userId, unprocessedOnly: true)`).
   - Busca contextos e projetos: `_projectsUseCase.getContexts()` e `getProjects()` (também do local).
2. O primeiro item da lista vira `_current`; o wizard é exibido para esse item.

### 6.2 Wizard (passo a passo)

1. **Passo 0 – “Isso exige ação?”**
   - **Sim** → `_requiresAction = true`, avança para o formulário de “próxima ação”.
   - **Não** → `_requiresAction = false`, avança para “O que fazer?”.

2. **Se não exige ação** (“O que fazer?”):
   - **Lixo**: só marca o item como processado (sem criar referência).
   - **Referência** ou **Algum dia/Talvez**: chama `_referenceUseCase.createReference(_current.content)` (grava no local + enfileira sync) e depois `_inboxUseCase.markProcessed(_current)` (atualiza local + enfileira sync).
   - Em seguida chama `_load()` de novo (próximo item ou lista vazia).

3. **Se exige ação**:
   - Usuário preenche: próxima ação (obrigatório), projeto (opcional), contexto (opcional), energia, tempo (min), aguardando (opcional).
   - **“Criar ação e processar”**:
     - `_actionsUseCase.createAction(...)`: cria `GtdAction` no local (status `next`) e enfileira sync para `gtd_actions`.
     - `_inboxUseCase.markProcessed(_current)`: marca o item do inbox como processado no local e enfileira sync para `gtd_inbox`.
     - `_load()`: recarrega lista e próximo item.

Todo dado é escrito primeiro no SQLite e na sync_queue; o Supabase é atualizado pelo **GtdSyncService** quando houver conexão.

---

## 7. Fluxo “Agora” (próximas ações)

- Lista vem do **local**: `_actionsUseCase.getNextActions(...)` → `GtdLocalStorage.getActions(userId, status: GtdActionStatus.next)`.
- Filtros (contexto, energia, com/sem data, busca por texto) são aplicados em memória sobre essa lista.
- **Swipe / ações**:
  - Concluir: `_actionsUseCase.completeAction(action)` → atualiza status para `done` no local e enfileira upsert.
  - Mover para “algum dia”: `_actionsUseCase.moveToSomeday(action)` → status `someday` no local e enfileira upsert.

Ou seja: leitura e escrita são sempre no SQLite; a sync_queue cuida de replicar no Supabase.

---

## 8. Fluxo Projetos

- Lista de projetos: **local** `getProjects(userId)`.
- Progresso (done/total): `getProjectProgress()` lê ações do local por projeto e conta quantas têm status `done`.
- Ao abrir um projeto: ações do projeto vêm do local (`getActionsByProject(projectId)`).
- “Adicionar ação”: `_actionsUseCase.createAction(title, projectId: _selected.id)` → grava no local e enfileira sync.

---

## 9. Fluxo Revisão semanal

- Checklist é apenas UI (inbox zero, projetos revisados, etc.).
- “Concluir revisão”: `_reviewUseCase.completeReview(notes)` → cria registro em `gtd_weekly_reviews` no local e enfileira sync para `gtd_weekly_reviews`.

---

## 10. Repositório remoto (Supabase)

- **GtdRemoteRepository** usa `SupabaseConfig.client` e **sempre** filtra por `user_id` (`.eq('user_id', userId)` ou equivalente).
- Não usa Supabase Auth para controle de acesso; o `userId` vem do Flutter (tabela `usuarios`).
- Operações: select, insert, update, upsert, delete nas tabelas `gtd_contexts`, `gtd_projects`, `gtd_inbox`, `gtd_reference`, `gtd_actions`, `gtd_weekly_reviews`.
- Datas são enviadas em UTC (ISO 8601); o Postgres armazena em `timestamptz`.

---

## 11. Resumo do fluxo de dados

```
[Usuário digita e salva]
        │
        ▼
┌───────────────────┐     ┌─────────────────────┐
│ GtdInboxUseCase   │────▶│ GtdLocalStorage     │
│ .capture(text)    │     │ .insertInbox(item)  │
│                   │     │ .enqueueSync(...)   │
└────────┬──────────┘     └─────────────────────┘
         │
         │ sync(userId) [em background]
         ▼
┌───────────────────┐     ┌─────────────────────┐
│ GtdSyncService    │────▶│ getPendingSyncItems │
│ .sync(userId)     │     │ → push (Supabase)   │
│                   │     │ → pull incremental  │
└───────────────────┘     └─────────────────────┘
         │
         ▼
┌───────────────────┐     ┌─────────────────────┐
│ GtdRemoteRepository│◀───│ Supabase (Postgres) │
│ .eq('user_id', …) │     │ gtd_* tables        │
└───────────────────┘     └─────────────────────┘
```

- **Escrita**: sempre primeiro no SQLite + entrada na sync_queue; depois o GtdSyncService envia ao Supabase quando há rede e respeitando `next_retry_at` e backoff.
- **Leitura**: a UI lê do SQLite (local); o pull atualiza o local a partir do Supabase com last-write-wins por `updated_at`.
- **Usuário**: em todo o fluxo o `user_id` vem de `GtdSession.currentUserId` (tabela `usuarios`), garantindo que cada usuário só vê e altera os próprios dados GTD.

Este é o fluxo completo do método GTD implantado, da captura à sincronização e às demais abas (Processar, Agora, Projetos, Revisão).
