# TaskFlow Design System — Roadmap de Implantação

> **Status:** Proposta de Planejamento  
> **Data:** Setembro de 2026

---

## 1. Visão Geral das Fases

```text
Q4 2026 / Q1 2027
Fase 0: Auditoria & Aprovação (ATUAL) ────────────────────────── [CONCLUÍDO]
Fase 1: Foundations & Theme Extensions (2 semanas) ───────────── [PRÓXIMO]
Fase 2: Componentes Atômicos & Feedback (2 semanas)
Fase 3: Formulários & Diálogos CRUD (3 semanas)
Fase 4: Tabelas, Filtros & Page Shell (4 semanas)
Fase 5: Migração Gradual de Telas Operacionais (6 semanas)
Fase 6: Homologação, Limpeza & Depreciação (2 semanas)
```

---

## 2. Detalhamento por Fase

### Fase 1: Foundations & Tokens
* **Objetivo:** Estabelecer a infraestrutura de código em `lib/design_system/foundations/` sem quebrar nenhuma tela existente.
* **Arquivos a Criar:**
  * `lib/design_system/foundations/tf_colors.dart`
  * `lib/design_system/foundations/tf_typography.dart`
  * `lib/design_system/foundations/tf_spacing.dart`
  * `lib/design_system/foundations/tf_radius.dart`
  * `lib/design_system/foundations/tf_elevation.dart`
  * `lib/design_system/foundations/tf_breakpoints.dart`
  * `lib/design_system/theme/taskflow_theme_extension.dart`
* **Dependências:** Nenhuma.
* **Risco:** Zero (não altera comportamento existente).
* **Critério de Aceite:** `flutter analyze` sem erros; `Theme.of(context).extension<TaskFlowThemeExtension>()` acessível em qualquer ponto do app.

### Fase 2: Componentes Atômicos & Feedback
* **Objetivo:** Criar os primeiros componentes reutilizáveis.
* **Arquivos a Criar:**
  * `lib/design_system/components/buttons/tf_button.dart`
  * `lib/design_system/components/buttons/tf_icon_button.dart`
  * `lib/design_system/components/status/tf_status_badge.dart`
  * `lib/design_system/components/feedback/tf_empty_state.dart`
  * `lib/design_system/components/feedback/tf_loading.dart`
* **Dependências:** Fase 1 concluída.
* **Critério de Aceite:** Widget tests cobrindo todos os estados e contrastes WCAG AA.

### Fase 3: Formulários & Diálogos
* **Objetivo:** Padronizar entradas de dados e migrar os 24 diálogos administrativos (`*_form_dialog.dart`).
* **Arquivos a Criar:**
  * `lib/design_system/components/inputs/tf_text_field.dart`
  * `lib/design_system/components/inputs/tf_dropdown.dart`
  * `lib/design_system/components/inputs/tf_search_field.dart`
  * `lib/design_system/components/dialogs/tf_dialog.dart`
  * `lib/design_system/components/dialogs/tf_confirm_dialog.dart`
* **Dependências:** Fase 2 concluída.
* **Critério de Aceite:** 100% dos formulários administrativos usando `TFFormDialog` com validação uniforme e sem erros de teclado/overflow.

### Fase 4: Dados, Filtros e Page Shell
* **Objetivo:** Criar o componente de tabela corporativa e o Page Shell padrão.
* **Arquivos a Criar:**
  * `lib/design_system/components/tables/tf_data_table.dart`
  * `lib/design_system/components/filters/tf_filter_bar.dart`
  * `lib/design_system/components/layout/tf_page.dart`
  * `lib/design_system/components/layout/tf_page_header.dart`
  * `lib/design_system/components/cards/tf_kpi_card.dart`
* **Dependências:** Fases 1, 2 e 3.

### Fase 5: Migração Piloto de Telas Operacionais (P0 e P1)
* **Objetivo:** Migrar gradualmente as telas centrais do sistema, mantendo compatibilidade retroativa:
  * **Lote A:** Telas de SAP (Notas SAP, Ordens, ATs, SIs).
  * **Lote B:** Demandas, Projetos e Documentos.
  * **Lote C:** Programação de Atividades e Gantt (em coordenação direta com equipe operacional).

### Fase 6: Depreciação de Código Legado
* **Objetivo:** Remover classes duplicadas de `form_dialog_helpers.dart`, descontinuar cores manuais e comemorar o atingimento do **Design Consistency Score $\ge 90/100$**.
