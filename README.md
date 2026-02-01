# Task Flow (task2026)

Task Flow e um app Flutter multiplataforma (web, desktop e mobile) para gestao
de tarefas, equipes e frota. O app integra com Supabase para dados e
sincronizacao, suporta modo offline com SQLite e inclui integracao
bidirecional com Telegram para chat e notificacoes.

## Principais recursos

- Gestao de atividades com tabela, Gantt, planner/kanban, calendario, feed
  e dashboards.
- Modulos de equipe, frota, manutencao, checklist, custos e alertas.
- Integracao com dados SAP (Notas, Ordens, ATs, SIs, horas).
- Chat interno com espelhamento e recebimento via Telegram.
- Albuns de imagens com anotacoes e organizacao por status.
- Mapas para linhas de transmissao e supressao de vegetacao.
- Offline-first: SQLite local, fila de sincronizacao e backoff.

## Arquitetura e componentes

- Flutter app em `lib/` com widgets, servicos e providers.
- Supabase em `supabase/` com migrations e Edge Functions
  (`telegram-webhook`, `telegram-send`).
- Migrations extras para albuns de midia em
  `lib/features/media_albums/migrations/`.
- Scripts operacionais e SQLs na raiz para deploy, diagnostico e correcoes.

## Estrutura do repositorio (resumo)

- `lib/` codigo Flutter e features.
- `android/`, `ios/`, `web/`, `macos/`, `windows/`, `linux/` alvos
  multiplataforma.
- `supabase/` migrations e functions.
- `*.sql`, `*.sh`, `*.ps1` scripts de manutencao e suporte.

## Configuracao local (Flutter)

1. Instale Flutter 3.8.1+ e Dart.
2. Atualize o Supabase em `lib/config/supabase_config.dart`
   (URL e anon key).
3. Instale dependencias:
   ```bash
   flutter pub get
   ```
4. Rode o app:
   ```bash
   flutter run -d chrome
   # ou: flutter run -d <device>
   ```

## Banco de dados (Supabase)

- Migrations principais: `supabase/migrations/`
- Migrations de albuns: `lib/features/media_albums/migrations/`
- Aplicar migrations:
  ```bash
  supabase db push
  ```

## Integracao Telegram

- Quick start: `README_TELEGRAM_QUICK_START.md`
- Documentacao completa: `INTEGRACAO_TELEGRAM.md`
- Checklist de testes: `CHECKLIST_TESTES_TELEGRAM.md`

## Deploy e operacao

- Deploy web: `DEPLOY_APLICACAO_WEB.md`
- Guia rapido Telegram (VPS): `GUIA_RAPIDO_DEPLOY.md`
- Comandos gerais: `COMANDOS_DEPLOY.md`

## Observacoes

- Substitua chaves e URLs sensiveis antes de usar em producao.
- Revise scripts e SQLs na raiz antes de executar.
