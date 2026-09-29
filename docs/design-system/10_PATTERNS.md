# TaskFlow Design System — Padrões de Layout (Page Shell)

> **Status:** Proposta Arquitetural  
> **Data:** Setembro de 2026

---

## 1. O Problema da Fragmentação de Telas

Atualmente, cada tela do TaskFlow monta seu layout de forma arbitrária:
* Telas como `NotasSAPView` criam um `Scaffold` com `AppBar` interna (duplicando a barra do `HeaderBar`).
* Telas como `DemandaDetailScreen` empilham containers com margens manuais de 16px ou 20px.
* Telas de listagem simples (`*_list_view.dart`) montam cabeçalhos com botões "Novo" desalinhados em relação às outras telas.

---

## 2. O Padrão Universal: `TaskFlowPage` (Page Shell)

Para eliminar essa inconsistência, toda e qualquer tela do TaskFlow passará a adotar a casca padronizada:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ TFPageHeader                                                           │
│ [Breadcrumbs: Home > Manutenção > Notas SAP]                          │
│                                                                        │
│ Título da Página (22px SemiBold)                 [Ações Secundárias]   │
│ Subtítulo explicativo ou metadados da tela       [+ Ação Primária]     │
├────────────────────────────────────────────────────────────────────────┤
│ TFFilterBar                                                            │
│ [ Busca... ] [ Regional v ] [ Status v ] [ Período v ] [ Limpar ]      │
├────────────────────────────────────────────────────────────────────────┤
│ Conteúdo Principal (TFPageContent)                                     │
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │                                                              │     │
│   │  Tabela / Gantt / Kanban / Grid / Cards / Formulário          │     │
│   │                                                              │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│ TFPageFooter (Opcional - Paginação / Totais / Status de Sync)         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Padrões Específicos por Tipo de Tela

### 3.1 Padrão "Tabela + Filtros" (Notas SAP, Ordens, Horas, Demandas)
* **Topo:** `TFPageHeader` com contagem total de registros em chip neutro (`"1.420 registros"`).
* **Filtros:** `TFFilterBar` horizontal fixa (com preservação de estado).
* **Corpo:** `TFDataTable` rolável com sticky headers e zebra striping.
* **Rodapé:** Paginação padronizada (`TFPagination`) e resumo de totais.

### 3.2 Padrão "Split Tabela + Gantt" (Programação de Atividades)
* Utiliza o componente [`ResizablePanel`](file:///Users/josepereiradasilvafilho/aplicativos/task/task2026/lib/widgets/resizable_panel.dart).
* Sincronização obrigatória de scroll vertical entre a tabela de atividades e as linhas do Gantt.
* Seletor de escala temporal (Diária, Semanal, Mensal, Horária) ancorado no topo do painel do Gantt.

### 3.3 Padrão "Master-Detail" (Projetos, Detalhes de Tarefa, Mídia)
* No Desktop: Lista à esquerda (35% a 40% da largura) e detalhes do item selecionado à direita (60% a 65%).
* No Mobile: Navegação padrão empilhada (Push/Pop na pilha de navegação).

### 3.4 Padrão "Dashboard Operacional"
* Linha superior com 4 a 6 `TFKpiCard`.
* Linha intermediária com gráficos de barras/linhas de cumprimento de cronograma e distribuição de prioridades.
* Linha inferior com tabela de ocorrências críticas e notas com prazo próximo de vencimento.
