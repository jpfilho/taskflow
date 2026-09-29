# TFDS Migration — Módulo de Melhorias e Bugs

## 1. Visão Geral

Este documento formaliza a migração visual e padronização com o **TaskFlow Design System (TFDS)** do módulo de **Melhorias e Bugs** (`lib/modules/melhorias_bugs/`), complementada com a adição de **busca textual local em memória**.

---

## 2. Arquitetura e Integridade Funcional

A camada de negócios, persistência offline-first e sincronização permaneceu **100% inalterada**:

- **Business Layer**: `MelhoriasBugsService` (Read-only)
- **Models**: `MelhoriaBug`, `Versao` (Read-only)
- **State Machine**: `kMelhoriasBugsTransicoes`, `kMelhoriasBugsStatusCodes` (Read-only)
- **Database / Offline**: SQLite (`LocalDatabaseService`) & Supabase (Read-only)
- **Sync**: `SyncService` (Read-only)

---

## 3. Arquivos de Apresentação Migrados

| Arquivo | Tipo | Componentes TFDS Utilizados |
| :--- | :--- | :--- |
| `melhorias_bugs_home_screen.dart` | Screen (Shell) | `context.tfColors`, `context.tfTypography`, `TabBar` padronizada |
| `melhorias_bugs_list_screen.dart` | Screen (List) | `TFPageHeader`, `TFCard`, `TFDropdown`, `TFSwitch`, `TFTextField` (busca local), `TFEmptyState`, `TFLoading` |
| `roadmap_board_screen.dart` | Screen (Roadmap) | `TFPageHeader`, `TFCard`, `TFStatusBadge`, `TFButton`, `TFEmptyState`, `TFLoading`, `LinearProgressIndicator` semântico |
| `versao_detail_screen.dart` | Screen (Detail) | `TFPageHeader`, `TFCard`, `TFStatusBadge`, `TFEmptyState`, `TFLoading`, `TFButton` |
| `melhoria_bug_card.dart` | Widget (Card) | `TFCard`, `TFStatusBadge`, `TFIconButton`, `context.tfColors`, `context.tfTypography` |
| `melhoria_bug_form_dialog.dart` | Widget (Dialog) | `TFFormDialog`, `TFTextField`, `TFDropdown`, `TFButton`, máquina de estados estrita |
| `versao_form_dialog.dart` | Widget (Dialog) | `TFFormDialog`, `TFTextField`, `TFButton` |

---

## 4. Busca Textual Local (In-Memory)

- **Campos pesquisados**: `titulo` e `descricao` (apenas se preenchida).
- **Normalização**: `trim().toLowerCase()` com match case-insensitive.
- **Isolamento**: Busca executada estritamente em memória na lista já carregada (`_filteredItems`), combinando com filtros de Tipo, Status e Apenas Ativos.
- **Preservação de Ordenação**: Mantém rigorosamente a ordenação original retornada pelo serviço/repositório.
- **Sem impactos de backend**: Zero queries de banco (SQLite/Supabase) modificadas.

---

## 5. Proteção da Máquina de Estados

- **Códigos de Status Reais**: `BACKLOG`, `ANALISE`, `DESENVOLVIMENTO`, `VALIDACAO`, `CONCLUIDO`, `REABERTO`, `REJEITADO`, `DUPLICADO`.
- **Mapeamento de Transições**: No modo de edição (`MelhoriaBugFormDialog`), apenas transições válidas mapeadas em `kMelhoriasBugsTransicoes[currentStatus]` são exibidas como opções no dropdown de status.
- **Status Inicial na Criação**: Novo item inicia obrigatoriamente no status `BACKLOG`.
- **Timestamps Automáticos**: `concluidoEm` e `reabertoEm` permanecem protegidos pelo serviço de domínio.

---

## 6. Resultados de Testes e Validação

- **Testes Unitários e de Widgets Dedicados**: `test/features/melhorias_bugs/melhorias_bugs_test.dart` (10 tests PASS / 0 FAIL).
- **Suíte Global de Testes**: 264 PASS / 0 FAIL.
- **Análise Estática Direcionada**: `flutter analyze lib/modules/melhorias_bugs/ test/features/melhorias_bugs/` (0 issues).
- **Temas**: Suporte completo a `Light`, `Dark` e `AXIA`.
- **Responsividade**: Validado em mobile (390px), tablet (768px/1024px) e desktop (1280px+).

---

## 7. Anexos / Evidências (Roadmap Futuro)

- **Status**: `ATTACHMENTS: HOLD`
- **Diretriz**: A funcionalidade de anexos e upload para Supabase Storage está pausada para uma fase posterior dedicada a storage unificado.
