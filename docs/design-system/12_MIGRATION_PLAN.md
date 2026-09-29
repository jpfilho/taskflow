# TaskFlow Design System — Plano de Migração Incremental

> **Status:** Proposta de Planejamento  
> **Data:** Setembro de 2026

---

## 1. Princípio Fundamental: Proibição de "Big Bang"

A substituição de toda a interface em uma única etapa (**Big Bang**) é estritamente **proibida**, pois acarreta altíssimo risco de:
* Regressão em funcionalidades operacionais sensíveis;
* Quebra de sincronização offline no SQLite;
* Erros de cálculo no Gantt e em prazos SAP;
* Impacto negativo na rotina diária dos usuários em produção.

A estratégia adotada será **convivência pacífica e incremental**: o código legado continuará funcionando normalmente enquanto novos componentes do `TaskFlow Design System` são introduzidos e adotados tela a tela.

---

## 2. Fases de Migração

```text
┌──────────────────────────────────────────────────────────────┐
│ FASE 0: Auditoria, Inventário e Especificação (ATUAL)       │
│ • Diagnóstico completo, documentação e aprovação arquitetural │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ FASE 1: Foundations & Tokens (Sem quebra de telas)           │
│ • Criação de lib/design_system/foundations/                  │
│ • TFColors, TFTypography, TFSpacing, TFRadius, TFElevation   │
│ • Integração via TaskFlowThemeExtension em ThemeService      │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ FASE 2: Componentes Atômicos & Feedback                      │
│ • TFButton, TFIconButton, TFStatusBadge, TFEmptyState        │
│ • Submissão de testes unitários e de acessibilidade          │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ FASE 3: Componentes de Formulário & Diálogos                 │
│ • TFTextField, TFDropdown, TFSearchField, TFDialog           │
│ • Modernização dos 24 formulários administrativos            │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ FASE 4: Componentes de Dados & Layouts                       │
│ • TFDataTable, TFFilterBar, TFPageHeader, TFKpiCard          │
│ • Padronização do Page Shell (TaskFlowPage)                  │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ FASE 5: Migração Gradual das Telas Operacionais (P0 e P1)    │
│ • Piloto 1: Telas Administrativas (baixo risco)             │
│ • Piloto 2: Notas SAP & Ordens (médio risco)                │
│ • Piloto 3: Atividades & Gantt (alto risco / isolado)        │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│ FASE 6: Limpeza & Depreciação de Componentes Legados         │
│ • Remoção de estilos duplicados e funções legadas            │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Matriz de Priorização da Migração

Para determinar a ordem exata de migração de cada uma das 135 telas, utilizamos a fórmula do **Migration Priority Score (MPS)**:

$$\mathbf{MPS} = \frac{(\text{Frequência de Uso} \times 3) + (\text{Dívida Visual} \times 2) + (\text{Impacto no Usuário} \times 2)}{(\text{Risco de Negócio} \times 2) + \text{Complexidade}}$$

* Onde cada variável é pontuada de 1 a 5.
* Telas com maior MPS são priorizadas (alto ganho com risco controlado).

### Ordem de Execução Recomendada:

1. **Lote 1 (Quick Wins / Baixo Risco - MPS > 4.0)**:
   * Telas de Configuração e Cadastros Administrativos (`*_list_view.dart` e `*_form_dialog.dart`).
   * `AlertsView`, `DocumentsPage`, `MelhoriasBugsHomeScreen`.
2. **Lote 2 (Operação Gerencial / Médio Risco - MPS 3.0 a 4.0)**:
   * `NotasSAPView`, `OrdemView`, `ATView`, `SIView`.
   * `DemandasScreen`, `ProjetosHomeScreen`.
3. **Lote 3 (Núcleo Operacional / Alto Risco - MPS < 3.0, requer cautela extrema)**:
   * `TaskTable` e `ActivityGanttView`.
   * `MainScreen` (Page Shell global).
