# Documentação oficial do módulo GTD (Getting Things Done) — TaskFlow

Documento baseado no **código real** do repositório. Referências a arquivos e classes correspondem ao que está implementado.

---

## A) Visão do módulo

### Objetivo

Implementar o método **Getting Things Done** no TaskFlow: **Capturar → Processar → Organizar → Revisar → Executar**, com persistência offline-first e sincronização ao Supabase.

### Abas (UI)

| Aba | Classe (Widget) | Arquivo | Função |
|-----|-----------------|---------|--------|
| Capturar | `GtdCaptureTab` | `lib/modules/gtd/presentation/tabs/gtd_capture_tab.dart` | Captura rápida no inbox |
| Processar | `GtdProcessTab` | `lib/modules/gtd/presentation/tabs/gtd_process_tab.dart` | Wizard item-a-item do inbox |
| Agora | `GtdAgoraTab` | `lib/modules/gtd/presentation/tabs/gtd_agora_tab.dart` | Próximas ações (status=next) com filtros e swipe |
| Projetos | `GtdProjectsTab` | `lib/modules/gtd/presentation/tabs/gtd_projects_tab.dart` | Projetos, progresso e ações do projeto |
| Revisão | `GtdWeeklyReviewTab` | `lib/modules/gtd/presentation/tabs/gtd_weekly_review_tab.dart` | Checklist + registro em `gtd_weekly_reviews` |

A página que contém as abas é **`GtdHomePage`** (`lib/modules/gtd/presentation/screens/gtd_home_page.dart`), com `DefaultTabController(length: 5)`.

### Filosofia no app

- **Offline-first**: toda escrita vai primeiro para o SQLite local (`GtdLocalStorage`) e para a fila `sync_queue`; o envio ao Supabase é assíncrono via `GtdSyncService`.
- **Fonte única de usuário**: `GtdSession.currentUserId` (não Supabase Auth); todas as queries locais e remotas filtram por `user_id`.
- **Leitura sempre local**: as abas leem do SQLite; o pull incremental atualiza o local a partir do Supabase.

---

## B) Modelo de dados

### Backend (Supabase / Postgres)

Migration: `supabase/migrations/20260205_gtd.sql`.

| Tabela | Campos essenciais | Observações |
|--------|-------------------|-------------|
| **gtd_contexts** | id, user_id, name, created_at, updated_at | UNIQUE(user_id, name) |
| **gtd_projects** | id, user_id, name, notes, created_at, updated_at | — |
| **gtd_inbox** | id, user_id, content, processed_at, created_at, updated_at | processed_at NULL = não processado |
| **gtd_reference** | id, user_id, title, content, created_at, updated_at | Referência / algum dia |
| **gtd_actions** | id, user_id, project_id, context_id, title, status, energy, time_min, due_at, waiting_for, notes, linked_task_id, created_at, updated_at | status: next \| waiting \| someday \| done; FKs opcionais para gtd_projects e gtd_contexts (ON DELETE SET NULL) |
| **gtd_weekly_reviews** | id, user_id, notes, completed_at, created_at, updated_at | Apenas insert (append-only) |

Todas as tabelas têm trigger `gtd_updated_at()` para atualizar `updated_at` em UPDATE. RLS está **desabilitado**; controle de acesso é por `user_id` no app.

### Espelho local (SQLite — sqflite)

Implementação: **`GtdLocalStorage`** (`lib/modules/gtd/data/local/gtd_local_storage.dart`). Banco: `gtd_local.db` (desktop/mobile) ou in-memory (web via `sqflite_common_ffi_web`).

Tabelas espelho: mesmos nomes e campos lógicos; datas em epoch (inteiro). Tabela adicional:

- **gtd_sync_queue**: id (AUTOINCREMENT), entity, entity_id, op, payload_json, created_at, next_retry_at, tries, last_error.

Modelos Dart: **`lib/modules/gtd/data/models/gtd_models.dart`** — `GtdContext`, `GtdProject`, `GtdInboxItem`, `GtdReferenceItem`, `GtdAction`, `GtdWeeklyReview`, `GtdSyncQueueItem`. Enum de status de ação: `GtdActionStatus` (next, waiting, someday, done).

### Invariantes

- **gtd_inbox**: `processed_at IS NULL` ⇒ item ainda não processado; `processed_at` preenchido ⇒ item já processado (destino implícito: ação, referência ou descarte).
- **gtd_actions**: `status` ∈ { next, waiting, someday, done }; ações com `project_id` pertencem ao projeto; `context_id` opcional; `linked_task_id` opcional (vínculo com tarefa do TaskFlow).
- **Sync**: toda escrita de entidade GTD (insert/update) deve ser seguida de `enqueueSync` com entity, entity_id, op (upsert/delete) e payload (para upsert).

---

## C) Máquinas de estados

### gtd_actions (status)

```
  [criação] → next
       │
       ├── completeAction()     → done
       ├── moveToWaiting(who)   → waiting  (waiting_for preenchido)
       ├── moveToSomeday()     → someday
       └── (permanece next até uma das transições acima)
```

- **next**: próxima ação executável (aba Agora lista apenas status=next).
- **waiting**: aguardando alguém/algo; `GtdActionsUseCase.moveToWaiting(action, waitingFor)`.
- **someday**: algum dia/talvez; `GtdActionsUseCase.moveToSomeday(action)`.
- **done**: concluída; `GtdActionsUseCase.completeAction(action)`.

Transições são feitas via `GtdActionsUseCase.updateAction` (ou métodos que dele dependem), que atualiza `updated_at` e persiste no local + sync_queue.

### gtd_inbox (processed_at; resultado não rastreado por tabela)

O schema **não** possui `result_type` nem `result_id`. Apenas:

- **processed_at IS NULL** ⇒ não processado (aparece no wizard da aba Processar).
- **processed_at NOT NULL** ⇒ processado (não aparece mais no wizard).

O “resultado” do processamento é implícito:

- Se usuário escolheu **Sim** (exige ação) → é criada uma linha em `gtd_actions` (e o inbox é marcado processado).
- Se escolheu **Não** e **Referência** ou **Algum dia** → é criada uma linha em `gtd_reference` (e o inbox é marcado processado).
- Se escolheu **Não** e **Lixo** → apenas marca processado (nenhuma linha em actions/reference).

**Extensão possível**: colunas `result_type` (action | reference | trash) e `result_id` (UUID da ação ou referência criada) para rastreabilidade.

---

## D) Fluxos detalhados

### D.1 Capturar

1. **GtdCaptureTab**: usuário digita no campo “O que está na sua cabeça?” e clica **Salvar** ou pressiona **Enter** (sem Shift).
2. **GtdCaptureTab._save()**: `content = controller.text.trim()`; se vazio, return; senão chama `_inboxUseCase.capture(content)`.
3. **GtdInboxUseCase.capture(content)**:
   - Obtém `userId = GtdSession.currentUserId`; se null, lança `StateError('Usuário não autenticado')`.
   - Cria `GtdInboxItem` (id UUID, userId, content, processedAt: null, createdAt/updatedAt UTC).
   - `GtdLocalStorage.insertInbox(item)` → insere em `gtd_inbox` (local).
   - `GtdLocalStorage.enqueueSync(entity: 'gtd_inbox', entityId: item.id, op: 'upsert', payload: item.toJson())`.
   - Chama `GtdSyncService.sync(userId)` (não espera).
4. **Resultado**: item aparece na lista da aba Capturar; fica na sync_queue para envio ao Supabase quando houver rede.

### D.2 Processar (wizard item-a-item)

1. **GtdProcessTab._load()**: `getInboxItems(unprocessedOnly: true)` (local), `getContexts()`, `getProjects()`; define `_current` = primeiro da lista não processada (ou null se vazio).
2. Se `_current == null` → mostra “Inbox zerado”.
3. **Passo 0** — “Isso exige ação?”  
   - **Sim** → `_requiresAction = true`, mostra formulário de próxima ação.  
   - **Não** → `_requiresAction = false`, mostra “O que fazer?” (Lixo, Referência, Algum dia/Talvez).
4. **Se não exige ação**:
   - **Lixo**: `_finishNoAction('trash')` → apenas `GtdInboxUseCase.markProcessed(_current)` (sem criar referência).
   - **Referência** ou **Algum dia/Talvez**: `_finishNoAction('reference'|'someday')` → `GtdReferenceUseCase.createReference(_current!.content)` (title=content, content=null) e `GtdInboxUseCase.markProcessed(_current)`.
   - Depois: `_load()` (próximo item).
5. **Se exige ação**:
   - Usuário preenche: Próxima ação (obrigatório), Projeto, Contexto, Energia, Tempo (min), Aguardando (opcional).
   - **“Criar ação e processar”**: `_finishWithAction()` valida `_nextActionTitle` não vazio; chama `GtdActionsUseCase.createAction(title: ..., projectId, contextId, energy, timeMin, dueAt, waitingFor)` e `GtdInboxUseCase.markProcessed(_current)`; depois `_load()`.

**Condições**: sempre ler/escrever no local; sync em background. Não há `result_type`/`result_id` no schema.

### D.3 Agora (próximas ações)

1. **GtdAgoraTab._load()**: `GtdActionsUseCase.getNextActions(contextId, energy, withDueOnly, withoutDueOnly, search)` → internamente `GtdLocalStorage.getActions(userId, status: GtdActionStatus.next)` e filtros em memória.
2. **Swipe**:
   - **Concluir** (startToEnd): `GtdActionsUseCase.completeAction(a)` → status done, local + sync_queue; depois `_load()`.
   - **Adiar** (endToStart): `GtdActionsUseCase.moveToSomeday(a)` → status someday, local + sync_queue; depois `_load()`.

### D.4 Projetos

1. Lista: `GtdProjectsUseCase.getProjects()` (local); progresso: `getProjectProgress()` (conta ações por projeto com status done/total).
2. Ao tocar em um projeto: `_openProject(p)` → `GtdActionsUseCase.getActionsByProject(p.id)` (local); exibe ações e botão “Adicionar ação”.
3. **Adicionar ação**: diálogo com título; `GtdActionsUseCase.createAction(title, projectId: _selected!.id)` → ação com status next; depois atualiza lista do projeto.

**Nota**: Criação de **projeto** ou **contexto** está implementada nos use cases (`GtdProjectsUseCase.createProject`, `createContext`) mas **não há botão na UI** atual; projetos/contextos precisam existir (ex.: criados fora ou por extensão futura) para aparecer nos dropdowns da aba Processar.

### D.5 Revisão semanal

1. **GtdWeeklyReviewTab**: checklist (Inbox zerado, Projetos revisados, etc.) preenchido com dados locais (`getInboxItems(unprocessedOnly: true)`, `getProjects()`); campo de notas.
2. **Concluir revisão**: `GtdWeeklyReviewUseCase.completeReview(notes)` → cria `GtdWeeklyReview` (completedAt, notes), `GtdLocalStorage.insertWeeklyReview(r)`, `enqueueSync(entity: 'gtd_weekly_reviews', ...)`, `GtdSyncService.sync(userId)`.

---

## E) Sincronização offline-first

### Push (sync_queue → Supabase)

- **GtdSyncService.sync(userId)** (em `lib/modules/gtd/data/gtd_sync_service.dart`): só roda se `ConnectivityService.isConnected` e não está `_isSyncing`.
- **GtdSyncService._pushQueue(userId)**:
  1. `GtdLocalStorage.getPendingSyncItems()` → itens com `next_retry_at <= now`, ordenados por `next_retry_at`.
  2. Para cada item: se `op == 'delete'` chama `_remoteDelete(entity, entityId, userId)`; senão `_remoteUpsert(entity, payload, userId)` (payload = JSON decodificado).
  3. Sucesso → `GtdLocalStorage.deleteSyncItem(item.id)`.
  4. Falha → backoff: `tries = item.tries + 1`, `backoffMs = min(baseBackoffMs * 2^tries, maxBackoffMs)` (baseBackoffMs=2000, maxBackoffMs=300000), `next_retry_at = now + backoffMs`; `GtdLocalStorage.updateSyncItemRetry(id, nextRetryAt, lastError)`.

### Pull incremental

- **GtdSyncService._pullIncremental(userId)**:
  - `after = _lastSyncAt ?? DateTime(1970)`.
  - Chama **GtdRemoteRepository**: `getContextsUpdatedAfter`, `getProjectsUpdatedAfter`, `getInboxUpdatedAfter`, `getActionsUpdatedAfter` (todos com `.eq('user_id', userId).gt('updated_at', after)`).
  - Para cada lista: faz **upsert local** (GtdLocalStorage.upsertContext, upsertProject, upsertInbox, upsertAction).
  - **Ordem**: contexts e projects antes de actions (respeita FK). **gtd_reference** e **gtd_weekly_reviews** não entram no pull (apenas push).

### Last-write-wins

- No pull, cada registro remoto é aplicado com upsert por `id` no SQLite; o servidor é a referência para o que mudou desde `lastSyncAt`. Conflitos de edição simultânea não são resolvidos por versão; o último `updated_at` que chegar no próximo pull “vence” no local.

### Quando o sync roda

- **GtdSyncService.initialize(userId)** (chamado em `GtdHomePage._initSync()`): conectividade, listener de reconexão, sync imediato, e `Timer.periodic(5 min)` (constante `syncIntervalMinutes = 5`).

### Diagrama simplificado (fluxo e sync_queue)

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                   ESCRITA (qualquer aba)                 │
                    │  UseCase (capture / createAction / markProcessed / etc.) │
                    └───────────────────────────┬─────────────────────────────┘
                                                │
                    ┌───────────────────────────▼─────────────────────────────┐
                    │  GtdLocalStorage                                          │
                    │  insert/update/upsert na tabela espelho + enqueueSync()   │
                    │  → gtd_sync_queue (entity, entity_id, op, payload_json…)   │
                    └───────────────────────────┬─────────────────────────────┘
                                                │
                    ┌───────────────────────────▼─────────────────────────────┐
                    │  GtdSyncService.sync(userId)                              │
                    │  1. _pushQueue: getPendingSyncItems → remote upsert/delete │
                    │     sucesso → deleteSyncItem; falha → updateSyncItemRetry │
                    │  2. _pullIncremental: remote get*UpdatedAfter → upsert   │
                    │     local (contexts, projects, inbox, actions)           │
                    │  3. _lastSyncAt = now                                    │
                    └───────────────────────────┬─────────────────────────────┘
                                                │
                    ┌───────────────────────────▼─────────────────────────────┐
                    │  GtdRemoteRepository (Supabase)                          │
                    │  .eq('user_id', userId) em todas as queries               │
                    └─────────────────────────────────────────────────────────┘
```

---

## F) Controle de acesso

- **user_id**: **`GtdSession.currentUserId`** (`lib/modules/gtd/domain/gtd_session.dart`). Fonte: `AuthServiceSimples().currentUser`; usa `user.id` se não vazio, senão `user.email`. Nunca `auth.uid()` do Supabase.
- **canAccessGtd**: **`GtdSession.canAccessGtd`**. Implementação atual: `user != null` (todo usuário autenticado). Para restringir (ex.: só root): alterar em `gtd_session.dart` para `return user?.isRoot ?? false;`.
- **Regras obrigatórias**:
  - Todas as leituras/escritas locais usam `userId` obtido de `GtdSession.currentUserId` (use cases).
  - Todas as chamadas ao **GtdRemoteRepository** recebem `userId` e o repositório aplica `.eq('user_id', userId)` (ou match em delete). Nunca confiar em RLS; RLS está desabilitado nas tabelas GTD.

---

## G) Casos de borda e decisões

- **Duplicidade**: IDs gerados no cliente (UUID) reduzem colisão; upsert por `id` no remoto e no local evita duplicar linha. Não há deduplicação por conteúdo.
- **Conflitos**: Last-write-wins por `updated_at` no pull; não há merge de campos nem versionamento. Edição offline + edição em outro dispositivo pode resultar em sobrescrita no próximo pull.
- **Delete**: Delete é hard-delete (remoto e local). `gtd_sync_queue` usa `op: 'delete'`; não há soft-delete nas tabelas GTD.
- **Integridade FK**: `gtd_actions.project_id` e `context_id` têm ON DELETE SET NULL no Postgres; no app, ao puxar ações, projetos/contextos são puxados antes no pull. Criação local de ação com project_id/context_id inválidos não é bloqueada pelo DB local (não há FK no SQLite).
- **Inbox “result”**: O destino do item processado (ação vs referência vs lixo) não fica registrado no registro do inbox; apenas `processed_at` é preenchido.

---

## H) Pontos de extensão

- **linked_task_id** (`gtd_actions`): coluna opcional para vincular ação GTD a uma tarefa do TaskFlow; UI de vínculo não implementada na documentação desta versão.
- **Agenda (due_at)**: Campo existente; aba Agora tem filtros “Com data” / “Sem data”. Listagem por data/agenda pode ser ampliada (ex.: vista calendário).
- **Aguardando (waiting)**: Status e `waiting_for` existem; `GtdActionsUseCase.moveToWaiting(action, waitingFor)`. Aba dedicada “Aguardando” não implementada; extensão possível.
- **Someday**: Status e movimento via `moveToSomeday`; lista “Algum dia” pode ser uma aba ou seção separada.
- **result_type / result_id no inbox**: Não implementado; extensão para rastrear para qual entidade (action/reference) o item foi processado.

---

## I) Checklist de QA

- **Offline captura**: Desligar rede → Capturar → salvar texto → item aparece na lista e persiste após reabrir app (SQLite).
- **Reconexão**: Com itens na sync_queue, ligar rede → sync deve rodar (ao abrir GTD ou por timer/reconexão) → itens devem sumir da fila e aparecer no Supabase.
- **Conflitos**: Dois dispositivos editam o mesmo registro; após syncs, o que tiver `updated_at` mais recente no servidor vence no pull (last-write-wins).
- **Retry**: Simular falha do Supabase (ex.: URL errada ou offline) → item permanece na sync_queue com `next_retry_at` e `tries` aumentando; ao voltar servidor, próximo sync deve enviar e remover da fila.
- **Timer**: Deixar app aberto no GTD com rede; após 5 minutos deve haver nova execução de sync (verificar logs ou lastSyncAt se exposto).
- **Processar**: Inbox com itens → Processar → Sim → preencher próxima ação → Criar ação e processar → item some do wizard e ação aparece em Agora/Projetos; Não → Referência → item some e referência criada (lista de referência não está na UI atual; pode checar no banco).
- **Acesso**: Sem login, `currentUserId` null → Capturar deve falhar com mensagem de login; com login, todas as abas devem ler/escrever apenas dados do usuário.

---

## Referência rápida de arquivos

| Camada | Arquivo | Responsabilidade |
|--------|---------|------------------|
| Presentation | `presentation/screens/gtd_home_page.dart` | Abas e init do sync |
| | `presentation/tabs/gtd_capture_tab.dart` | Captura |
| | `presentation/tabs/gtd_process_tab.dart` | Wizard processar |
| | `presentation/tabs/gtd_agora_tab.dart` | Próximas ações |
| | `presentation/tabs/gtd_projects_tab.dart` | Projetos |
| | `presentation/tabs/gtd_weekly_review_tab.dart` | Revisão semanal |
| Domain | `domain/gtd_session.dart` | currentUserId, canAccessGtd |
| | `domain/usecases/gtd_inbox_usecase.dart` | capture, getInboxItems, markProcessed |
| | `domain/usecases/gtd_actions_usecase.dart` | createAction, updateAction, completeAction, moveToSomeday, moveToWaiting, getNextActions, getActionsByProject |
| | `domain/usecases/gtd_projects_usecase.dart` | getContexts, createContext, getProjects, createProject, getProjectProgress |
| | `domain/usecases/gtd_reference_usecase.dart` | createReference, getReferenceItems |
| | `domain/usecases/gtd_weekly_review_usecase.dart` | completeReview, getWeeklyReviews |
| Data | `data/models/gtd_models.dart` | Modelos e enum GtdActionStatus |
| | `data/local/gtd_local_storage.dart` | SQLite (sqflite) + sync_queue |
| | `data/remote/gtd_remote_repository.dart` | Supabase (todas as queries com user_id) |
| | `data/gtd_sync_service.dart` | Push + pull, backoff, timer 5 min |

Integração no app: **main.dart** (rota índice 25 → `GtdHomePage`), **sidebar** (item “GTD” com `showGtd`). Migrations Supabase: **supabase/migrations/20260205_gtd.sql**.
