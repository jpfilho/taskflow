# Módulo GTD (Getting Things Done) - TaskFlow

Módulo GTD completo com captura, processamento do inbox, próximas ações, projetos e revisão semanal. Offline-first com sincronização ao Supabase.

## Requisitos

- Flutter 3.8+
- Supabase (Postgres) com as tabelas GTD criadas
- Usuário autenticado no app (AuthServiceSimples); **não** usa Supabase Auth para controle de acesso

## 1. Rodar migrations no Supabase

Execute a migration que cria as tabelas GTD no Postgres:

```bash
# No diretório do projeto
supabase db push
# ou aplique manualmente o arquivo:
# supabase/migrations/20260205_gtd.sql
```

O arquivo `supabase/migrations/20260205_gtd.sql` cria:

- `gtd_contexts` – contextos (ex: @casa, @trabalho)
- `gtd_projects` – projetos
- `gtd_inbox` – inbox (captura rápida)
- `gtd_reference` – referência / algum dia
- `gtd_actions` – ações (next, waiting, someday, done), com `linked_task_id` opcional para vincular à tarefa do TaskFlow
- `gtd_weekly_reviews` – revisões semanais

Todas as tabelas têm `user_id` (TEXT). O controle de acesso é feito no Flutter; **não** há RLS baseado em `auth.uid()`.

## 2. Ligar o módulo no app

O módulo já está integrado:

- **Menu**: item "GTD" no sidebar (índice 25), visível se `GtdSession.canAccessGtd` for true (por padrão, todo usuário autenticado).
- **Rota**: ao selecionar GTD no menu, é exibida a `GtdHomePage` com abas: Capturar, Processar, Agora, Projetos, Revisão.

Para restringir o acesso (ex.: só root):

- Em `lib/modules/gtd/domain/gtd_session.dart`, altere `canAccessGtd` para `return user?.isRoot ?? false;`.

## 3. Estrutura do módulo

```
lib/modules/gtd/
├── data/
│   ├── local/          # SQLite (sqflite) – tabelas espelho + sync_queue
│   ├── remote/         # Supabase – repositório remoto (filtro por user_id)
│   ├── models/         # Modelos GTD
│   └── gtd_sync_service.dart  # Push da fila + pull incremental
├── domain/
│   ├── gtd_session.dart       # userId e canAccessGtd
│   └── usecases/              # Inbox, Actions, Projects, Reference, WeeklyReview
└── presentation/
    ├── screens/        # GtdHomePage
    ├── tabs/           # Capturar, Processar, Agora, Projetos, Revisão
    └── widgets/        # GtdCard, GtdEmptyState
```

## 4. Rodar na web

Se for usar o GTD no navegador (Flutter web), rode o setup do SQLite para web **uma vez**:

```bash
dart run sqflite_common_ffi_web:setup
```

Isso copia `sqlite3.wasm` e `sqflite_sw.js` para a pasta `web/`. Depois disso, o GTD usa SQLite em memória na web (dados locais até recarregar a página).

## 5. Testar offline

1. **Captura offline**: desligue a internet, abra GTD → Capturar, digite um texto e salve. O item deve aparecer na lista e ser gravado no SQLite local.
2. **Sync ao voltar**: ligue a internet. Ao abrir o app ou ao entrar no GTD, o sync roda (e a cada 5 min em background). O item deve ser enviado ao Supabase.
3. **Fila e backoff**: se o servidor estiver indisponível, a operação fica na `sync_queue` e será reenviada com backoff exponencial (2s, 4s, 8s… até 5 min).

## 6. Sincronização

- **Escrita local**: toda criação/edição/exclusão persiste no SQLite e enfileira um item na `sync_queue` (entity, entity_id, op, payload_json, next_retry_at, tries, last_error).
- **Push**: o scheduler envia itens da fila ao Supabase (respeitando `next_retry_at` e backoff).
- **Pull**: incremental por `updated_at > lastSyncAt`; last-write-wins com `updated_at`.
- **Ordem**: contexts e projects antes de actions; upserts idempotentes.

## 7. Dependências novas

- `timezone` – datas em UTC no backend e conversão no app.

O banco local GTD usa **sqflite** (já presente no projeto); não é usado DRIFT nesta implementação.

## 8. Testes

```bash
flutter test test/modules/gtd/
```

Testes incluídos:

- Enqueue de sync (inserção na fila após escrita local).
- Merge last-write-wins (comparação por `updated_at`).
- Validações do wizard de processamento do inbox (ex.: próxima ação obrigatória quando “exige ação”).

## 9. Integração com tarefas (TaskFlow)

A tabela `gtd_actions` tem a coluna opcional `linked_task_id` (UUID). O app pode vincular uma ação GTD a uma tarefa existente do sistema; o schema atual do TaskFlow não é alterado.
