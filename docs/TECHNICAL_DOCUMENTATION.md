# Documentação Técnica — Task Flow

Sistema de Gestão de Tarefas corporativo multiplataforma (Android, iOS, Web e Desktop), com estratégia offline-first e sincronização com Supabase.

---

## 1. Visão Geral do Sistema

### Objetivo da aplicação

O **Task Flow** é um sistema de gestão de atividades, ordens de serviço, equipes, frota, horas e integrações SAP (Notas, Ordens, ATs, SIs). Permite planejamento em tabela e Gantt, detecção de conflitos de alocação, chat por comunidades/grupos, anexos, módulo GTD e funcionalidades de supressão de vegetação e linhas de transmissão.

### Público-alvo

- Equipes de campo e escritório que precisam planejar e acompanhar tarefas.
- Coordenadores e gerentes que alocam executores e frotas.
- Usuários que precisam acessar dados mesmo sem conexão (offline-first).
- Administradores (usuários root) que configuram dashboards, documentos, demandas e relatórios.

### Principais problemas que o sistema resolve

- Centralizar atividades, ordens, equipes e frota em uma única aplicação.
- Permitir uso em campo com ou sem internet (cache local e fila de sincronização).
- Evitar conflitos de alocação (mesmo executor em locais distintos no mesmo dia) via views e alertas.
- Integrar com dados SAP (notas, ordens, ATs, SIs, horas) e exibir encerramento/conformidade.
- Oferecer chat por comunidade (regional/divisão/segmento) e por grupo vinculado à tarefa.
- Suportar múltiplas plataformas (mobile, web, desktop) com uma única base de código Flutter.

---

## 2. Arquitetura Geral

### Visão de alto nível

- **Frontend:** aplicação Flutter (lib/) — UI, estado da tela, chamadas a serviços.
- **Backend:** Supabase (PostgreSQL, Auth, Storage, Realtime) — dados mestres, usuários, anexos, chat, views materializadas.
- **Sync:** camada no próprio app (SyncService + LocalDatabaseService) — fila de operações, tabelas locais com `sync_status`, pull/push.
- **Offline:** SQLite local (sqflite / sqflite_common_ffi / sqflite_common_ffi_web) — cache de tarefas, segmentos Gantt, usuários, cadastros e fila de sync.

### Diagrama textual da arquitetura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FLUTTER APP (task2026)                           │
├─────────────────────────────────────────────────────────────────────────┤
│  UI (main.dart, widgets/, features/, modules/)                           │
│       │                                                                  │
│       ▼                                                                  │
│  Services (TaskService, AuthServiceSimples, SyncService,                 │
│            LocalDatabaseService, ConnectivityService, AnexoService,      │
│            ChatService, ConflictService, ExecutorService, FrotaService…) │
│       │                    │                                             │
│       ▼                    ▼                                             │
│  SQLite Local ◄────── SyncService ──────► Supabase (PostgreSQL,         │
│  (tasks_local,            ▲               Storage, Realtime)              │
│   gantt_segments_local,   │                                               │
│   sync_queue,            │ ConnectivityService                           │
│   usuarios_local, …)     │                                               │
└─────────────────────────┼───────────────────────────────────────────────┘
                          │
                    connectivity_plus
                          │
┌─────────────────────────▼───────────────────────────────────────────────┐
│  Rede (HTTP/HTTPS) → Supabase URL (ex.: 212.85.0.249:8000)               │
│  API Node (ex.: 212.85.0.249:3001) — webhooks, geo, etc.                 │
└──────────────────────────────────────────────────────────────────────────┘
```

### Comunicação entre camadas

- A UI dispara ações (carregar tarefas, criar/editar/excluir, login, sync).
- Os **Services** decidem: se há conectividade, usam Supabase e atualizam o SQLite; se não há, usam apenas SQLite e enfileiram operações.
- O **SyncService** escuta `ConnectivityService.connectionStream` e, ao reconectar, executa `syncAll()` (fila + tabelas pendentes + pull).
- Autenticação: **AuthServiceSimples** usa **UsuarioService** (Supabase `usuarios` quando online; tabela `usuarios_local` quando offline; sessão persistida em FlutterSecureStorage/SharedPreferences e AuthCacheService).

---

## 3. Stack Tecnológica

| Componente | Tecnologia |
|------------|------------|
| **Frontend** | Flutter (SDK >=3.8.1 <4.0.0), flutter_localizations |
| **Plataformas** | Android, iOS, Web, Linux, macOS, Windows |
| **Backend / BaaS** | Supabase (URL e anon key em `lib/config/supabase_config.dart`) — Auth, Database (PostgreSQL), Storage, Realtime |
| **Banco local** | SQLite via sqflite (mobile), sqflite_common_ffi (desktop), sqflite_common_ffi_web (web com IndexedDB/FFI) |
| **Conectividade** | connectivity_plus |
| **Auth local** | FlutterSecureStorage, SharedPreferences, AuthCacheService |
| **Outros** | http, file_picker, image_picker, uuid, crypto, path_provider, permission_handler, local_auth (biometria), pdf, excel, fl_chart, flutter_map, timezone (GTD), etc. |

### Serviços auxiliares

- **API Node** (`apiBaseUrl` em SupabaseConfig): webhooks, integração geo/Telegram (porta 3001).
- **Telegram:** integração opcional (telegram_identities, telegram_subscriptions, telegram_delivery_logs, comunidades/tarefas).
- **Web:** `VersionCheckService` (version_check_service_web) consulta `version.txt` na origem para avisar nova versão e permitir reload.

### Bibliotecas principais

- supabase_flutter, sqflite, sqflite_common_ffi, sqflite_common_ffi_web
- connectivity_plus, flutter_secure_storage, path_provider
- flutter_gantt (Gantt), file_picker, image_picker, cached_network_image, photo_view
- uuid, crypto, intl, timezone

---

## 4. Estrutura do Projeto

```
task2026/
├── lib/
│   ├── config/           # SupabaseConfig (URL, anon key, initialize)
│   ├── data/              # mock_data (dados de exemplo)
│   ├── features/          # media_albums, documents (estrutura por feature)
│   ├── models/             # Task, GanttSegment, Usuario, Anexo, Ordem, NotaSAP, etc.
│   ├── modules/            # gtd (domain, presentation)
│   ├── providers/           # theme_provider
│   ├── services/            # auth, sync, local_db, connectivity, task, anexo, chat, conflict, etc.
│   ├── utils/               # responsive, conflict_detection, platform_file_io, web_download
│   ├── widgets/             # sidebar, header_bar, task_table, gantt_chart, login_screen, chat_view, etc.
│   └── main.dart            # inicialização (SQLite factory, Supabase, LocalDB, Connectivity, Sync), MyApp, AuthWrapper, MainScreen
├── supabase/migrations/     # migrations SQL (telegram, GTD, geo, conflict views, etc.)
├── android/, ios/, web/, linux/, macos/, windows/
├── build_android.sh, build_ios.sh
└── docs/
```

### Responsabilidade das camadas

- **config:** configuração global (Supabase).
- **models:** entidades de domínio (Task, Usuario, Anexo, etc.).
- **services:** regras de negócio, acesso a Supabase e SQLite, fila de sync, conectividade.
- **widgets:** telas e componentes reutilizáveis; leem serviços e estado do MainScreen.
- **main.dart:** orquestra AuthWrapper, MainScreen, sidebar (índice → view), filtros, carregamento de tarefas e permissões (root, coordenador/gerente para edição).

### Padrões adotados

- **Singleton para serviços:** TaskService(), SyncService(), LocalDatabaseService(), ConnectivityService(), AuthServiceSimples(), etc.
- **Repository implícito:** serviços acessam Supabase e/ou LocalDatabaseService diretamente (não há camada Repository explícita em todos os casos).
- **Controller/State:** MainScreen e telas são StatefulWidgets com estado local; ThemeProvider para tema.
- **Streams:** ConnectivityService.connectionStream, SyncService.syncingStream para UI (ex.: SyncStatusWidget).

---

## 5. Modelo de Dados

### Tabelas principais (Supabase / espelho local)

- **tasks** / **tasks_local:** tarefas (id, status, regional, divisão, local, segmento, tipo, ordem, tarefa, executor(es), frota, coordenador, si, data_inicio/fim, observações, horas, prioridade, parent_id, etc.). Local inclui `sync_status`, `last_synced`.
- **gantt_segments** / **gantt_segments_local:** segmentos do Gantt por tarefa (task_id, data_inicio, data_fim, label, tipo, tipo_periodo). Local: `sync_status`, `last_synced`.
- **usuarios** / **usuarios_local:** usuários (id, email, nome, ativo, is_root). Perfil em usuarios_regionais, usuarios_divisoes, usuarios_segmentos. Local guarda senha_hash para login offline.
- **regionais, divisoes, segmentos, locais, executores, tipos_atividade, status, feriados** (e tabelas _local correspondentes): cadastros mestres.
- **anexos** / **anexos_local:** anexos por tarefa (task_id, nome_arquivo, tipo_arquivo, caminho_arquivo/url, tamanho). Storage em bucket Supabase.
- **sync_queue:** fila de operações (table_name, operation, record_id, data JSON, synced, status, retry_count, backoff_ms, next_retry_at, last_error).
- **comunidades, grupos_chat, mensagens:** chat por comunidade (regional/divisão/segmento) e por grupo vinculado à tarefa.
- **demandas, demand_attachments:** demandas e anexos de demandas (bucket demands-attachments).
- **GTD:** gtd_contexts, gtd_projects, gtd_inbox, gtd_reference, gtd_actions, gtd_weekly_reviews (migrations 20260205+).
- **Conflitos:** views `v_conflict_por_dia_executor`, `v_conflict_execution_events` (backend).
- **Execuções/horas:** views como `v_execucoes_dia_completa`, `mv_execucoes_dia`, `v_execucoes_dia_frota`, `tasks_encerramento_sap`.

### Relacionamentos

- Task → status, regional, divisão, segmento, locais (N:N), executores (N:N), equipes, frota; parent_id para subtarefas.
- GanttSegment → task_id (FK).
- Anexo → task_id (FK).
- Usuario → regionais, divisões, segmentos (perfil de acesso).
- Chat: Comunidade → Grupos; Grupo → tarefa; Mensagens por grupo.

### Campos relevantes

- **tasks:** id (UUID), status/status_id, regional_id, divisao_id, segmento_id, local_id/equipe_id (legado), precisa_si, data_inicio/data_fim, created_at/updated_at.
- **sync_queue:** operation (insert/update/delete), status (pending, retrying, failed, done).
- **usuarios_local:** senha_hash para validação offline (hash da senha em texto).

### Integridade e regras de negócio

- Subtarefas: parent_id aponta para task.id.
- Sincronização: registros com `sync_status = 'pending'` são enviados ao Supabase; após sucesso, marcados `synced` e `last_synced` atualizado.
- Conflitos: definidos no backend (mesmo executor, mesmo dia, mais de um local); app consome views e exibe alertas/tooltips.
- Permissão de edição de tarefas: apenas usuários root ou coordenador/gerente (ExecutorService.isCoordenadorOuGerentePorLogin).

### Formação dos segmentos do Gantt (tela Atividades)

Na tela de **Atividades**, o Gantt recebe sempre `tasks: _sortedTasks` (derivado de `_tasks`), `startDate: _startDate`, `endDate: _endDate`, e `tasksForConflictDetection: _tasksSemFiltros` (ou `_tasks` se não houver base sem filtro). Os **segmentos** exibidos vêm das tarefas retornadas por `TaskService.filterTasks()`; a formação depende de estar **sem filtros** ou **com filtros** e de usar **cache local** ou **Supabase**.

- **Sem filtros (status/regional/divisão/local/tipo/executor/coordenador/frota):**
  - `main.dart` chama `filterTasks(..., dataInicioMin: _startDate, dataFimMax: _endDate)` sem os demais parâmetros → resultado em `_tasks` e `_tasksSemFiltros`.
  - O Gantt usa essas mesmas tarefas; cada barra é desenhada a partir de `task.ganttSegments`.

- **Com filtros:**
  - `main.dart` chama primeiro `filterTasks` só com datas → `baseTasks` (`_tasksSemFiltros`).
  - Depois chama `filterTasks` com status, regional, divisão, local, tipo, executor, coordenador, frota e as mesmas datas → `filtered` → `_tasks`.
  - O Gantt recebe `_sortedTasks` (ordenado a partir de `_tasks`), então só vê tarefas que passaram nos filtros; os segmentos continuam sendo `task.ganttSegments` de cada tarefa retornada.

- **Origem dos segmentos em `filterTasks`:**
  - **Cache (shouldUseLocal):** tarefas vêm de `_getAllTasksFromLocal()`; cada tarefa é montada em `_taskFromLocalMap()` com `gantt_segments_local` lidos do SQLite. As datas dos segmentos são interpretadas com `DateTime.fromMillisecondsSinceEpoch(..., isUtc: true)` para evitar deslocamento de um dia (UTC vs local). O filtro por período usa os segmentos para decidir se a tarefa entra no intervalo `[_startDate, _endDate]` (overlap por dia civil).
  - **Supabase:** a query busca tarefas (com filtros quando aplicados); em seguida `_loadGanttSegmentsBatch(taskIds, dataInicioMin: _startDate, dataFimMax: _endDate)` carrega da view/tabela `gantt_segments` no backend (já filtrada por período). Os segmentos são anexados a cada tarefa; opcionalmente há um refinamento em memória por `dataInicioMin`/`dataFimMax` antes de montar a lista final.

Em ambos os caminhos, as barras do Gantt são posicionadas usando `segment.dataInicio` e `segment.dataFim` (ano/mês/dia) sem nova conversão de fuso; a correção com `isUtc: true` no cache garante alinhamento entre dados do Supabase e do cache.

---

## 6. Autenticação e Segurança

### Fluxo de login

1. **Login com email e senha:** AuthServiceSimples.signInWithEmail → UsuarioService.fazerLogin. Se online: busca em Supabase `usuarios` (com perfil), salva em `usuarios_local` com senha (hash) e em cache; se offline: valida contra `usuarios_local` (senha_hash).
2. **Registro:** signUpWithEmail → criar em Supabase e salvar local + cache.
3. **Sessão:** email salvo em FlutterSecureStorage e SharedPreferences; ao abrir o app, restoreSession() tenta AuthCacheService, depois usuario local por email, depois Supabase por email.
4. **Logout:** signOut() limpa usuário atual, session e AuthCacheService.
5. **Azure AD:** signInWithAzureEmail (opcional, pode estar desativado na tela de login).

### Funcionamento offline

- Login offline: possível se o usuário já tiver feito login uma vez (email + senha gravados em usuarios_local com senha_hash). restoreSession() usa obterUsuarioLocalPorEmail e AuthCacheService.
- Criação/edição de tarefas offline: gravadas no SQLite com sync_status = 'pending' e/ou enfileiradas em sync_queue; sincronizadas quando a rede voltar.

### Regras de acesso

- **Root (is_root):** acesso a todas as telas (Dashboard, Documento, Lista, Gráfico, Alertas, Histórico, Checklist, Custos, Demandas, Linhas de Transmissão, Documentos, etc.).
- **Coordenador/Gerente:** podem criar/editar tarefas (verificação via ExecutorService).
- **Perfil do usuário:** regionalIds, divisaoIds, segmentoIds limitam quais dados o usuário vê (filtros aplicados nas consultas).
- **GTD e Supressão de Vegetação:** controlados por GtdSession.canAccessGtd (ex.: root ou email específico jpfilho@axia.com.br).

### Tokens e permissões

- Supabase: uso da anon key em supabase_config; RLS no backend define acesso por usuário/role.
- App não implementa refresh de JWT Supabase Auth neste fluxo; autenticação é via tabela `usuarios` e sessão própria (email + cache/local).

---

## 7. Estratégia Offline-First

### O que funciona offline

- Login (se já logado antes e usuário está em usuarios_local).
- Listagem e visualização de tarefas e segmentos já cacheados no SQLite.
- Criação e edição de tarefas e segmentos Gantt (gravados localmente com sync_status pending e/ou na sync_queue).
- Navegação nas telas que dependem apenas de dados já baixados (cadastros, filtros).
- Tema e preferências locais.

### O que não funciona offline

- Login pela primeira vez (depende de Supabase ou de ter usuário em usuarios_local).
- Upload de anexos (Supabase Storage).
- Chat (mensagens e listagem de comunidades/grupos).
- Dados em tempo real (Realtime).
- Views de conflito, execuções diárias, encerramento SAP (consultas diretas ao Supabase).
- Verificação de nova versão (web, version.txt).
- Sincronização (pull/push).

### Cache local

- SQLite: tasks_local, gantt_segments_local, usuarios_local, regionais_local, divisoes_local, segmentos_local, locais_local, executores_local, tipos_atividade_local, status_local, feriados_local, frota_local, anexos_local.
- TTL: TaskService usa _tasksCacheTtl (ex.: 30 minutos) como referência; LocalDatabaseService.isCacheFresh(localTable, ttl) verifica max(last_synced) vs TTL.
- Web: SQLite em memória (inMemoryDatabasePath) ou IndexedDB conforme sqflite_common_ffi_web.

### Fila de sincronização

- sync_queue: operações insert/update/delete com table_name, record_id, data (JSON). status: pending, retrying, failed, done.
- SyncService.syncAll() processa sync_queue primeiro, depois tabelas _local com pending, depois pull (tasks, gantt_segments).
- Retry: até _maxRetries (5), backoff exponencial (_baseBackoffMs 2s, _maxBackoffMs 5min); itens com next_retry_at no futuro não são processados até o momento indicado.

### Tratamento de conflitos

- **Conflitos de alocação (executor/dia):** backend expõe v_conflict_por_dia_executor e v_conflict_execution_events; ConflictService busca e a UI (ex.: Gantt/TeamSchedule) exibe indicadores e tooltips.
- **Conflitos de dados (mesmo registro editado em dois lugares):** não há merge automático; last_synced e updated_at do Supabase são usados no pull para atualizar local se o remoto for mais recente. Edições locais pendentes são enviadas na ordem da fila; sobrescrita depende da ordem e das regras do backend.

### Riscos conhecidos

- Web: banco em memória não persiste entre reloads; fila e dados locais podem se perder.
- Muitos itens pendentes na sync_queue podem atrasar a sincronização; itens permanentemente falhos (status failed) permanecem até limpeza manual ou implementação de UI para isso.
- Login offline depende de ter feito login online pelo menos uma vez (ou de ter usuário inserido em usuarios_local por outro meio).
- Conflitos de edição simultânea (dois dispositivos no mesmo registro) podem resultar em sobrescrita sem aviso explícito de conflito de versão.

---

## 8. Sincronização de Dados

### Quando ocorre

- Ao iniciar o app, se ConnectivityService.isConnected (após ~800 ms).
- Ao reconectar (ConnectivityService.connectionStream).
- Manualmente: botão "Sincronizar" na UI (SyncStatusWidget ou equivalente), que chama SyncService.syncAll().

### Como ocorre

1. **Fila (sync_queue):** para cada item pendente (e next_retry_at <= now): insert/update/delete no Supabase; em sucesso markAsSynced; em falha, backoff e markAsFailed ou markAsPermanentlyFailed após max retries.
2. **Tabelas locais:** para cada tabela (tasks_local, gantt_segments_local, usuarios_local, regionais_local, …), registros com sync_status = 'pending' são enviados (insert ou update no Supabase) e depois marcados synced.
3. **Pull:** _pullFromSupabase baixa tasks e gantt_segments do Supabase (limit 1000, order updated_at desc) e insere/atualiza em tasks_local e gantt_segments_local; atualiza apenas se updated_at do remoto for maior que o local.

### Serviços envolvidos

- SyncService (orquestra).
- LocalDatabaseService (sync_queue, tabelas _local, getPendingSyncCount, getPendingSyncItems, updateSyncStatus, getMaxLastSynced).
- ConnectivityService (isConnected, connectionStream).
- SupabaseConfig.client (insert, update, delete, from().select()).

### Estratégia de retry

- Backoff exponencial: 2s, 4s, 8s, 16s, 32s (limitado a 5 min).
- next_retry_at gravado para não reprocessar antes da hora.
- Após 5 falhas: markAsPermanentlyFailed (status = 'failed').

### Tratamento de falhas

- Erros logados em print; sync_queue item fica retrying ou failed.
- Cooldown (_syncCooldown 2s) após fim de syncAll() para evitar nova sync imediata (ex.: após loadTasks).
- Na web, SyncStatusWidget não é exibido (sincronização não é usada da mesma forma).

---

## 9. Fluxos Principais do Sistema

### Criação de registros

- **Tarefa:** UI (TaskFormDialog) → TaskService.createTask → se online: Supabase insert + atualização local; se offline: insert em tasks_local (sync_status pending) e/ou addToSyncQueue. Subtarefas: createSubtask.
- **Segmento Gantt:** criação/edição no GanttChart ou telas de equipe/frota → TaskService atualiza segmentos; lógica similar (Supabase + local ou só local + fila).
- **Usuário:** registro na tela de login → AuthServiceSimples.signUpWithEmail → UsuarioService.criarUsuario (Supabase) e salvamento local.
- **Anexo:** AnexoService.uploadAnexo (file ou bytes) → Storage Supabase + insert em `anexos`.
- **Demanda / anexo de demanda:** DemandAttachmentService.uploadFile/uploadBytes → bucket demands-attachments + tabela demand_attachments.
- **Chat:** mensagens via ChatService; comunidades criadas/obtidas por combinação regional/divisão/segmento (ChatView).

### Edição

- Tarefas e segmentos: TaskService.updateTask, atualização de segmentos; mesmo padrão online vs offline (Supabase + local ou só local + sync_queue update).
- Perfil do usuário: atualização no Supabase e AuthServiceSimples.atualizarUsuarioAtual + cache.

### Exclusão

- Tarefa: TaskService.deleteTask → delete no Supabase e/ou delete local + sync_queue delete.
- Anexo: remoção no Storage e na tabela anexos.
- Demand attachments: DemandAttachmentService.deleteAttachment.

### Upload de arquivos

- **Anexos de tarefa:** AnexoService — file_picker/image_picker → arquivo ou bytes → Supabase Storage (bucket por taskId/timestamp-nome) + insert em `anexos`. Download via URL assinada ou equivalente.
- **Demandas:** DemandAttachmentService — bucket demands-attachments, tabela demand_attachments.
- **Documentos / Álbuns:** features/documents e features/media_albums com repositórios Supabase e upload específico por contexto.

### Chat / mensagens

- ChatView: lista comunidades (por regional/divisão/segmento das tarefas); ao selecionar comunidade, lista grupos; ao selecionar grupo, abre ChatScreen.
- Mensagens: envio e listagem via ChatService (Supabase: mensagens, grupos_chat, comunidades). Suporte a texto, possivelmente anexos/áudio conforme implementação do ChatScreen.

---

## 10. Logs, Monitoramento e Debug

### Onde ficam os logs

- Saída padrão (print/debugPrint) no console onde o app está rodando (flutter run, IDE, dispositivo).
- Erros de renderização: capturados por ErrorWidget.builder em main.dart (exibe tela de erro e stack no app).
- Supabase: logs no dashboard do projeto (API, Postgres, Auth, Storage).
- Servidor Node (webhooks/geo): logs do processo (pm2, systemd, etc.).

### Como depurar

- Flutter: `flutter run`, DevTools, breakpoints.
- Verificar ConnectivityService.isConnected e SyncService.isSyncing para problemas de sync.
- LocalDatabaseService: consultar sync_queue e tabelas _local (sync_status, last_synced) para ver pendências.
- Supabase: SQL Editor para views (v_conflict_*, v_execucoes_dia_*, tasks_encerramento_sap) e tabelas.
- Web: console do navegador; VersionCheckService em debug não mostra banner de nova versão.

### Pontos críticos

- Inicialização: ordem main() — databaseFactory (SQLite), Supabase.initialize(), LocalDatabaseService().database, ConnectivityService, SyncService. Se algum falhar, o app continua com mensagem no console (ex.: "Continuando sem banco local").
- Carregamento de tarefas: _loadTasks no MainScreen; filtros por perfil (regionalIds, divisaoIds, segmentoIds) e filtros de tela; _tasks vs _tasksSemFiltros (equipe/frota usam sem filtros).
- Permissão de edição: _loadTaskEditPermission (root ou coordenador/gerente); _ensureCanEditTasks antes de criar/editar tarefa.

---

## 11. Build e Deploy

### Android

- Script: `./build_android.sh` (incrementa build number, flutter clean, flutter pub get, build apk ou app bundle).
- Opções: `--no-clean`, `--no-version`.
- Saída: `build/app/outputs/` (APK ou AAB conforme script).
- Variáveis: nenhuma obrigatória no script; Supabase em código (supabase_config.dart).

### iOS

- Script: `./build_ios.sh` — incrementa build, flutter clean, pub get, pod install, remove frameworks de simulador do bundle, build (ipa ou xcarchive).
- Requer: Xcode, CocoaPods, certificados e provisioning para distribuição.
- Documento auxiliar: `ios/ERROS_UPLOAD_APP_STORE.md` se existir.

### Web

- Build: `flutter build web`.
- Deploy: publicar conteúdo de `build/web/` em servidor estático ou CDN.
- version.txt: colocar na raiz do deploy (conteúdo = versão/build ou timestamp) para VersionCheckService mostrar "Nova versão disponível" e botão "Atualizar agora".
- SQLite na web: sqflite_common_ffi_web (IndexedDB ou em memória); não persiste entre reloads como em mobile/desktop.

### Variáveis de ambiente

- Não há uso de dart-defines ou --dart-define no projeto para URLs/keys; Supabase URL e anon key estão em `lib/config/supabase_config.dart`. Para ambientes diferentes (dev/prod), alterar esse arquivo ou introduzir variáveis de ambiente e leitura no código.
- API Node (apiBaseUrl): mesma configuração em supabase_config.dart.

### Configurações necessárias

- Supabase: projeto com tabelas e RLS aplicados (migrations em supabase/migrations/).
- Storage: buckets para anexos de tarefas e para demands-attachments (e outros que as features usem).
- Android: minSdkVersion e permissões em android/app/build.gradle e AndroidManifest (câmera, armazenamento, localização, etc., conforme uso).
- iOS: permissões e capabilities no Xcode (Keychain, etc.).
- Web: CORS e HTTPS conforme servidor; version.txt para aviso de nova versão.

---

## 12. Limitações Conhecidas

- **Web:** banco SQLite em memória ou volátil; sincronização e indicador de pendentes não são mostrados da mesma forma que em mobile; dados locais podem se perder ao fechar a aba.
- **Autenticação:** não usa Supabase Auth (email/senha) nativo; usa tabela `usuarios` e sessão própria; "esqueci minha senha" não envia e-mail (apenas verifica existência do usuário).
- **Conflitos de edição:** não há merge automático nem alerta de "conflito de versão" ao sobrescrever; last-write-wins baseado em updated_at no pull.
- **Fila de sync:** itens permanentemente falhos não são limpos automaticamente pela UI; não há tela de administração da sync_queue.
- **Escalabilidade:** pull com limit 1000; para grandes volumes pode ser necessário paginação ou filtros por data/regional.
- **Permissões:** regras de coordenador/gerente dependem de dados em executores/equipes no backend; se não configurados, apenas root pode editar tarefas.
- **Telegram / Node:** dependem de servidor e configuração externa; documentação em arquivos como BOTOES_INLINE_TELEGRAM.md, CHECKLIST_TESTES_TELEGRAM.md.

### Melhorias futuras recomendadas

- Persistência SQLite na web (ex.: wasm + persistence) ou aceitar que web seja sempre online.
- Tela de "Esqueci minha senha" com envio de e-mail (Supabase Auth ou serviço próprio).
- UI para visualizar e limpar itens da sync_queue (pendentes e falhos).
- Conflito de versão: detectar updated_at no push e avisar usuário antes de sobrescrever.
- Paginação ou incremental sync no pull (por data, por regional).
- Documentar e padronizar uso de variáveis de ambiente para URL/keys (dev/staging/prod).
- Testes automatizados (unit e widget) para serviços críticos (sync, auth, task CRUD).
