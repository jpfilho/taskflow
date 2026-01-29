# Análise da tela de Atividades e de todas as suas visualizações

Este documento descreve o funcionamento da **tela de Atividades** (sidebar índice 0) e da **tela de ATs** (sidebar índice 18), incluindo todas as visualizações, fluxos de dados e componentes envolvidos.

---

## 1. Tela "Atividades" (sidebar índice 0)

**Rota no app:** primeiro item da sidebar — **"Atividades"** (ícone `Icons.grid_view`).  
É a tela principal do Taskflow: lista e gerencia **tarefas** (tasks), com várias formas de visualização.

### 1.1 Onde é definida

- **`lib/main.dart`**: conteúdo da tela é decidido em `_buildMainContent()` e `_getViewBySidebarIndex()` quando `_sidebarSelectedIndex == 0`.
- **Mobile/Tablet:** uso de `_buildMobileContentStack()` para trocar entre abas (Tabela, Gantt, Planner, etc.).
- **Desktop:** lógica por `_viewMode` e `_showGantt` para escolher tabela, tabela+Gantt ou uma view específica (Planner, Calendário, Feed, Dashboard).

### 1.2 Modos de visualização (Footbar)

Na **footbar** (barra inferior), quando a tela Atividades está ativa, aparecem 5 botões que alteram `_viewMode`:

| Botão        | Modo        | Descrição breve |
|-------------|-------------|------------------|
| Tabela/Gantt| `split`     | Tabela de tarefas e/ou Gantt (conforme toggle). |
| Planner     | `planner`   | Kanban (PlannerView). |
| Calendário  | `calendar`  | Calendário de manutenção (MaintenanceCalendarView). |
| Feed        | `feed`      | Cards de tarefas (TaskCardsView). |
| Dashboard   | `dashboard` | Dashboard de tarefas (Dashboard). |

- **Mobile:** `_selectedTab` é sincronizado com o modo (0=Tabela, 1=Gantt, 2=Planner, 3=Calendário, 4=Feed, 5=Dashboard) e o conteúdo vem de `_buildMobileContentStack()`.
- **Desktop:** o conteúdo é escolhido diretamente por `_viewMode` em `_buildMainContent()` (Dashboard, PlannerView, MaintenanceCalendarView, TaskCardsView ou Tabela ± Gantt).

### 1.3 Componentes por modo

- **Tabela**
  - **Widget:** `TaskTable` (`lib/widgets/task_table.dart`).
  - Exibe tarefas em colunas (ações, status, local, tipo, tarefa, executor, coordenador, frota, chat, anexos, notas SAP, ordens, ATs, SIs, etc.).
  - Suporta ordenação, expansão de subtarefas, seleção, edição, exclusão, duplicação, criação de subtarefa.
  - Callbacks: `onTaskSelected` → `_showTaskDetails`, `onEdit`, `onDelete`, `onDuplicate`, `onCreateSubtask`.

- **Gantt**
  - **Widget:** `GanttChart` (`lib/widgets/gantt_chart.dart`).
  - Usado junto com a tabela (desktop: lado a lado; mobile: no modo split ou na aba 1).
  - Recebe `_sortedTasks`, `_startDate`, `_endDate`, `taskService` e callbacks de atualização/edição/exclusão/duplicação/subtarefa.

- **Planner (Kanban)**
  - **Widget:** `PlannerView` (ex.: `lib/widgets/planning_view.dart` ou equivalente).
  - Recebe `_sortedTasks`, `taskService`, `onTasksUpdated`, `onTaskSelected`, `onEdit`, `onDelete`, `onDuplicate`, `onCreateSubtask`.

- **Calendário**
  - **Widget:** `MaintenanceCalendarView` (`lib/widgets/maintenance_calendar_view.dart`).
  - Recebe `_tasks` (tarefas filtradas), `taskService` e callbacks de edição/exclusão/duplicação/subtarefa.

- **Feed**
  - **Widget:** `TaskCardsView` (`lib/widgets/task_cards_view.dart`).
  - Lista tarefas em cards; mesmos callbacks de edição/exclusão/duplicação/subtarefa.

- **Dashboard**
  - **Widget:** `Dashboard` (`lib/widgets/dashboard.dart` ou `comprehensive_dashboard.dart`).
  - Recebe `taskService` e `_sortedTasks` (tarefas filtradas).

### 1.4 Fluxo de dados (Atividades)

- Tarefas vêm de `_loadTasks()` em `main.dart` e são filtradas/ordenadas em `_sortedTasks`.
- Filtros são aplicados via `_applyFilters(_currentFilters)`; na tela Atividades (`_sidebarSelectedIndex == 0`) os filtros são reaplicados quando necessário.
- **HeaderBar** (e em mobile o toggle na barra) controla `_showGantt` (exibir ou não o Gantt ao lado da tabela).
- Diálogos comuns: `TaskFormDialog` (criar/editar), `TaskViewDialog` (detalhes), além de outros para exclusão/duplicação/subtarefas.

### 1.5 Responsividade

- **Mobile:** conteúdo único por vez via `_buildMobileContentStack()` (Tabela, Gantt, Planner, Calendário, Feed ou Dashboard) conforme `_selectedTab` / `_viewMode`; footbar troca o modo.
- **Tablet:** mesmo esquema de stack da Atividades (`_buildMobileContentStack()` quando índice 0).
- **Tablet landscape (largura &lt; 1280):** também usa `_buildMobileContentStack()` para Atividades.
- **Desktop (largura ≥ 1280):** tabela e Gantt em linha (ou só tabela), ou uma única view em tela cheia (Planner, Calendário, Feed, Dashboard).

---

## 2. Tela "ATs" (sidebar índice 18)

**Rota no app:** item da sidebar **"ATs"** (ícone `Icons.assignment`).  
Exibe **Autorizações de Trabalho (ATs)** do SAP e sua relação com tarefas do Taskflow (vinculação e estatísticas).

**Arquivo principal:** `lib/widgets/at_view.dart` — widget `ATView`.

### 2.1 Estrutura geral da ATView

A tela é um `Scaffold` com `body` em `Column`:

1. **Header** (fixo)
2. **Filtros** (opcional, controlado por "Mostrar/Esconder filtros")
3. **Abas de gráficos** (3 abas; podem ser ocultadas ao expandir a tabela)
4. **Contador de resultados** (total de ATs e “nesta página”)
5. **Lista de ATs** (Cards ou Tabela)
6. **Paginação** (quando total &gt; 50)

### 2.2 Header

- Título: **"ATs"**.
- **Três cards de estatísticas** (calculados sobre `_todasATs` e `_atsProgramadasIds`):
  - **ATs Programadas** (quantidade e % do total) — cor azul.
  - **AT's Concluídas** (status usuário contendo "CONC") — cor verde.
  - **Não Programadas** (total − programadas) — cor laranja.
- Botão **Mostrar/Esconder filtros** (alterna `_filtrosVisiveis`).
- Botão **Alternar visualização** (ícone tabela/cards): alterna `_visualizacaoTabela` (false = cards, true = tabela). No desktop, o padrão é tabela.
- Botão **Atualizar** (limpa filtros e recarrega ATs e estatísticas).

### 2.3 Filtros

Quando `_filtrosVisiveis` é true:

- **Status Sistema** — multi-seleção (`_filtroStatus`), valores de `_statusDisponiveis`.
- **Local de Instalação** — multi-seleção (`_filtroLocal`), valores de `_locaisDisponiveis`.
- **Status Usuário** — multi-seleção (`_filtroStatusUsuario`), valores de `_statusUsuarioDisponiveis`.
- **Data Início** e **Data Fim** — seletores de data (`_dataInicio`, `_dataFim`).
- **Ano Fim** e **Mês Fim** — dropdowns (`_filtroAnoFim`, `_filtroMesFim`), preenchidos por `_recalcularAnosMesesFim()` a partir de `_todasATs`.

Qualquer mudança de filtro zera `_paginaAtual`, chama `_loadATs()` e `_loadTodasATsParaEstatisticas()`.

### 2.4 Gráficos (3 abas)

Usam `_todasATs` (ATs já filtradas, sem paginação). Se `_tabelaExpandida` for true, a área de abas é ocultada.

- **Aba "Barras"** — `_buildATsPorFimBaseChart(isMobile)`  
  - Gráfico de barras por mês/ano da **data fim** da AT.  
  - Contagem por status: ignora CANC; considera CRSI e CONC para a barra total; CONC também para uma série “concluídas”.  
  - Duas barras por mês: uma para total (CRSI+CONC), outra para concluídas (CONC). Cores: azul/vermelho (atraso) e verde.

- **Aba "Distribuição"** — `_buildDistribuicaoATsHeatmap(isMobile)`  
  - Heatmap: linhas = centro de trabalho (`cntrTrab`), colunas = mês/ano da data fim.  
  - Valor da célula = quantidade de ATs naquele centro naquele mês. Escala de cor (branco → azul).

- **Aba "Evolução"** — `_buildEvolucaoATsAcumulada(isMobile)`  
  - Gráfico de linhas (fl_chart): evolução **acumulada** por mês.  
  - Duas linhas: ATs programadas (vinculadas a tarefa) e ATs concluídas (status usuário CONC).

Botão **Expandir tabela** (ícone fullscreen) ao lado das abas define `_tabelaExpandida = true`, esconde os gráficos e mostra só a tabela (com botão “Restaurar gráficos” para voltar).

### 2.5 Lista de ATs: Cards vs Tabela

- **Carregamento:** `_loadATs()` busca ATs paginadas (50 por página, `_paginaAtual`, `_itensPorPagina`) via `ATService.getAllATs()` com os filtros e período atual. O total vem de `ATService.contarATs()`.
- **Estatísticas e gráficos:** usam `_todasATs` (todas as ATs do filtro, sem limite), carregadas em `_loadTodasATsParaEstatisticas()`.

**Modo Cards** (`_visualizacaoTabela == false`):

- `ListView.builder` de `_buildATCard(at)`.
- Cada card é um `ExpansionTile`: avatar com status, título "AT: {autorzTrab}", e ao expandir mostra detalhes (status sistema/usuário, edificação, texto breve, local, SI, Cen, CntrTrab, datas, etc.).
- Se a AT está **programada** (em `_atsProgramadasIds`), o card mostra vínculo com tarefa (nome, status da tarefa, botão para abrir tarefa ou “Ver todas” se houver mais de uma vinculação).
- Ações no card: **Criar Tarefa**, **Vincular a Tarefa**, **Copiar AT**, e ao clicar na AT ou na tarefa vinculada abre detalhes ou `TaskViewDialog`.

**Modo Tabela** (`_visualizacaoTabela == true` ou `_tabelaExpandida`):

- `_buildTabelaView()`: `DataTable` com scroll horizontal.
- Colunas: Ações, Status, Tarefa Vinculada, AT, Tipo, Texto Breve, Status Sistema, Status Usuário, Local Instalação, Início Base, Fim Base, GPM.
- Por linha: botões “Criar Tarefa” e “Vincular a Tarefa”; célula de status (programada com badge da tarefa ou “Não Programada”); link para tarefa vinculada (ou diálogo com todas as vinculações); cópia do número da AT; clique na AT abre `_mostrarDetalhesAT(at)`.

### 2.6 Vinculação AT ↔ Tarefa

- **ATs programadas:** `_loadATsProgramadas()` chama `_service.getATsProgramadas()` e preenche `_atsProgramadasIds` e `_atsProgramadasInfo` (por AT, lista de vínculos com tarefa e `vinculado_em`).
- **Criar tarefa a partir da AT:** `_criarTarefaDaAT(at)` abre `TaskFormDialog` com datas sugeridas (início/fim da AT), ao salvar cria a tarefa e chama `_service.vincularATATarefa(createdTask.id, at.id)`, depois recarrega programadas.
- **Vincular a tarefa existente:** `_vincularATATarefaExistente(at)` abre `TaskSelectionDialog`; ao escolher tarefa chama `_service.vincularATATarefa(tarefa.id, at.id)` e recarrega programadas.
- **Ver tarefa:** `_navegarParaTarefa(taskId)` abre `TaskViewDialog` com a tarefa carregada por `TaskService.getTaskById`.
- **Ver todas as vinculações de uma AT:** `_mostrarTodasVinculacoes(at, vinculacoes)` abre um `AlertDialog` com lista de tarefas vinculadas; cada item pode abrir `TaskViewDialog`.

### 2.7 Diálogos e detalhes

- **Detalhes da AT:** `_mostrarDetalhesAT(at)` — `AlertDialog` com campos da AT (autorzTrab, tipo, status sistema/usuário, texto breve, denominação local/objeto, local instalação, SI, GPM, datas, etc.) e botão copiar AT.
- **Criar tarefa:** `TaskFormDialog`.
- **Seleção de tarefa:** `TaskSelectionDialog`.
- **Visualizar tarefa:** `TaskViewDialog`.
- Filtros multi-seleção: uso de `MultiSelectFilterDialog` (ou equivalente) para status/local/status usuário.

### 2.8 Modelo e serviço

- **Modelo:** `lib/models/at.dart` — classe `AT` (id, autorzTrab, edificacao, local, localInstalacao, textoBreve, datas, statusUsuario, statusSistema, cntrTrab, cen, si, etc.). `fromMap` para Supabase, `fromCSVParts` para importação CSV.
- **Serviço:** `lib/services/at_service.dart` — `ATService`:
  - `getAllATs(...)` e `contarATs(...)` com filtros e período.
  - `getATsProgramadas()` para vínculos AT–tarefa.
  - `vincularATATarefa(taskId, atId)`.
  - Importação de ATs a partir de CSV (`importarATsDoCSV`).
- **Status:** cores de status de tarefa vêm de `StatusService` e `_statusMap`; cores de status sistema da AT vêm de `_getStatusColor` (ABER, CAPC, DMNV, ERRD, SCDM, etc.).

### 2.9 Paginação

- Contador: “Total: X ATs (Y nesta página)” e “Página P de N”.
- Botões Anterior/Próximo alteram `_paginaAtual` e chamam `_loadATs()` (não recarrega `_todasATs` nem gráficos, que já usam o conjunto filtrado completo).

---

## 3. Resumo rápido

| Tela          | Sidebar      | Conteúdo principal                                      | Visualizações |
|---------------|-------------|----------------------------------------------------------|----------------|
| **Atividades**| Índice 0    | Tarefas do Taskflow (TaskTable, Gantt, etc.)            | Tabela, Tabela+Gantt, Planner, Calendário, Feed, Dashboard |
| **ATs**       | Índice 18   | Autorizações de Trabalho (SAP) e vínculo com tarefas     | Cards, Tabela + 3 gráficos (Barras, Distribuição, Evolução) |

- **Atividades:** múltiplas views sobre a mesma lista de tarefas (`_sortedTasks`), controladas por footbar e, no mobile, por abas.
- **ATs:** uma única tela (ATView) com filtros, indicadores, gráficos e lista (cards ou tabela) de ATs, com ações de criar/vincular tarefas e abrir detalhes da AT ou da tarefa vinculada.

Se quiser, posso aprofundar em um único componente (por exemplo só ATView ou só a lógica da footbar no main) ou gerar um diagrama de fluxo em texto para uma dessas telas.
