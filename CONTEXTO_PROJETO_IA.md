# Contexto do Projeto para Agentes de IA - Task Flow (task2026)

Este arquivo serve como o **ponto central de conhecimento da arquitetura e das regras do sistema Task Flow**, projetado para ser lido por agentes de Inteligência Artificial (IA) antes de realizarem alterações no código.

## 1. Visão Geral
**Task Flow** é um aplicativo multiplataforma (Web, Desktop, iOS, Android) voltado para gestão de tarefas, equipes, frota e manutenção. O sistema integra-se diretamente com o Supabase como backend primário e possui sincronização offline-first utilizando SQLite local. Também conta com uma integração forte e bidirecional com o Telegram e com o SAP (Notas, Ordens, Horas).

## 2. Stack Tecnológica
- **Frontend**: Flutter (Dart) com suporte multiplataforma.
- **Backend / BaaS**: Supabase (PostgreSQL, Auth, Storage, Edge Functions, RLS).
- **Banco Local (Offline)**: SQLite via `sqflite` (e `sqflite_common_ffi` para web/desktop).
- **Estado e Integração**: Utiliza providers/services nativos e hooks próprios, com chamadas REST (HTTP) e SDK do Supabase (`supabase_flutter`).
- **Automações Externas**: Webhooks Node.js, `n8n`, scripts Shell/PowerShell (para devops e integrações locais).
- **Mapas e Geo**: `flutter_map` com suporte a KML.
- **Gráficos e Agendamento**: `flutter_gantt`, `fl_chart`, calendários customizados.

## 3. Arquitetura Frontend (`lib/`)
A organização do Flutter segue uma estrutura mista de camadas lógicas e features isoladas:

- **`lib/main.dart`**: Entrypoint do app. Inicializa Supabase, SQLite, Serviços de Conectividade e Sync.
- **`lib/features/`**: Módulos fortemente isolados:
  - `ai_assistants`: Assistentes de IA.
  - `chat_feedback`: Sistema de conversas/feedbacks.
  - `demandas`: Módulo de solicitações/demandas.
  - `documents` & `media_albums`: Gerenciamento de arquivos, documentos e álbuns de fotos.
  - `warnings`: Alertas.
- **`lib/modules/`**: Módulos globais como `gtd` (Getting Things Done) e `melhorias_bugs`.
- **`lib/services/`**: Camada de regra de negócio e comunicação de rede (ex: `task_service.dart`, `sync_service.dart`, `local_database_service.dart`, `executor_service.dart`, `frota_service.dart`, `chat_service.dart`).
- **`lib/models/`**: Classes de modelo de dados (POJOs em Dart com `fromJson`/`toJson`).
- **`lib/widgets/`**: Componentes de UI reutilizáveis e telas principais (Tabelas, Dashboards, Gantt, Formulários).
- **`lib/config/`**: Configurações da aplicação (ex: `supabase_config.dart`, temas, menus).

## 4. Arquitetura Backend e Dados (Supabase)
O banco de dados é PostgreSQL hospedado no Supabase. O esquema principal engloba (ver `supabase_schema.sql` na raiz):
- **Gestão Organizacional**: `regionais`, `divisoes`, `segmentos`, `centros_trabalho`, `empresas`.
- **Recursos Humanos e Físicos**: `executores`, `equipes`, `frota`.
- **Atividades**: `tasks` (com relacionamentos parentais e `status`: ANDA, CONC, PROG), `gantt_segments`.
- **Integração SAP**: `notas_sap`, `ordens`, `sis`, `horas_sap` (e suas respectivas tasks de junção).
- **Engajamento e Comunicação**: `telegram_communities`, tabelas de mensagens de chat.
- **RLS (Row Level Security)**: Habilitado nas tabelas. Agentes não devem desativar RLS; qualquer alteração de permissão deve ser explicada.

## 5. Módulos Críticos e Integrações
1. **Offline-First (`SyncService` e `LocalDatabaseService`)**: As alterações locais são salvas no SQLite e sincronizadas em background via `SyncService` quando há rede. Nunca assuma conectividade constante no front-end.
2. **Integração Telegram**: A comunicação (via bot) reflete ações do app (ex: chats vinculados a notas/tarefas). Webhooks rodam em Edge Functions ou em servidores paralelos (n8n/Node.js scripts).
3. **Integração SAP**: Componentes específicos (SIs, ATs, Ordens, Notas) mapeiam a realidade industrial/elétrica. Use as views preparadas (`criar_view_notas_sap_com_prazo.sql`, etc.) para consultas otimizadas.
4. **DevOps Local**: A pasta raiz contém centenas de scripts `.ps1`, `.sh` e `.sql` usados para debug, setup e deploy (ex: correções de nginx, deploy ssl, proxy pass n8n).

## 6. Diretrizes de Desenvolvimento para IA
- **Entendimento Prévio**: Nunca altere a estrutura do banco sem uma migration formal. Use SQL explícito para criar/alterar tabelas no Supabase.
- **Reutilização UI**: Se precisar de uma tela de "visualização" ou "cadastro", procure em `lib/widgets/` se algo parecido já existe (ex: `task_form_dialog.dart`, `advanced_list_view.dart`).
- **Padrão de Tela e Responsividade**: As interfaces usam `LayoutBuilder` / `MediaQuery` (ou classes como `Responsive` em `utils/responsive.dart`) para ajustar o design a Web e Mobile.
- **Tratamento de Estado**: Prefira a estrutura existente baseada no ecossistema local (Providers / State Management usado, muitas vezes `StatefulWidget` com Services globais ou Singletons).
- **Sem Destruição de Código**: Evite remover lógicas complexas de sincronização, queries complexas (views/joins) ou handlers do Telegram sem autorização explícita do usuário.
- **Documentação Opcional, Código Legível**: Comente decisões complexas, especialmente em integrações com SAP ou scripts de sincronização de tarefas.

## Resumo de Localização Rápida para IA
- Arquivo central do banco de dados: `supabase_schema.sql` (e pasta `supabase/migrations/`).
- Entrypoint frontend: `lib/main.dart`
- Serviços centrais: `lib/services/`
- Páginas da interface: Principalmente em `lib/widgets/` ou `lib/features/<nome>/presentation/screens/`.
- Regras gerais e checklist do usuário (Humano): Checar diretório `.agents/rules/` e arquivos `.md` espalhados na raiz (ex: `RESUMO_IMPLEMENTACAO_TELEGRAM.md`).
