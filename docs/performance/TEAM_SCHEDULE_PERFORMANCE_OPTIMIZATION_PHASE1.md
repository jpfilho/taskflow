# TASKFLOW — TEAM SCHEDULE PERFORMANCE
## FASE 1 — OTIMIZAÇÃO CONTROLADA DOS GARGALOS COMPROVADOS

**Data da Otimização**: 17/09/2026  
**Ambiente**: Backend Supabase em Produção (`http://212.85.0.249:8000`)  
**Período de Referência**: 01/06/2026 a 30/06/2026 (30 dias)  
**Arquivo Alvo**: `lib/widgets/team_schedule_view.dart`  

---

## 1. RESUMO EXECUTIVO DO RESULTADO

A Fase 1 atacou exclusivamente os gargalos comprovados na auditoria, com foco em redução de queries redundantes, paralelização de rede e indexação em memória $O(1)$, sem nenhuma alteração no banco de dados, views SQL ou geometria do Gantt.

| Métrica | BEFORE (Auditoria) | AFTER (Fase 1) | Ganho / Redução |
| :--- | :---: | :---: | :---: |
| **Tempo Total do Pipeline** | **10.840 ms** | **4.511 ms** | **-6.329 ms (-58,4%)** |
| **Pipeline de Conflitos** | **4.901 ms** | **982 ms** | **-3.919 ms (-80,0%)** |
| **Re-query de Tarefas** | **1.480 ms** | **0 ms** | **-1.480 ms (-100,0%)** |
| **Cargas de Metadados** | **1.200 ms** (sequencial) | **1.156 ms** (paralelo) | **Otimizado** |
| **View de Execuções (`v_execucoes_dia_completa`)** | 1.990 ms | 2.222 ms | Preservada para Fase 2 |
| **Processamento CPU Dart** | 60 ms | 14 ms | **-46 ms (-76,7%)** |
| **Chamadas a `isTaskAssignedToExecutor`** | **249.228** | **0** | **-100,0%** (via índice $O(1)$) |
| **Buscas Lineares de Tarefas por ID** | **1.135.741** | **0** | **-100,0%** (via índice $O(1)$) |
| **Montagem de Linhas (`_buildExecutorRowsFromView`)** | 2 vezes | 1 vez | **-50,0%** |
| **Queries Supabase Totais** | 16 queries | 14 queries | -2 queries |

---

## 2. OTIMIZAÇÕES IMPLEMENTADAS

### Otimização #1 — Filtrar Executores na Consulta de Conflitos
- **Antes**: Enviava todos os ~420 executores cadastrados no sistema para `getConflictsForRange` e `getExecutionEventsForRange`, varrendo períodos de centenas de profissionais sem nenhuma tarefa programada no período.
- **Depois**: Extrai exclusivamente os `relevantExecutorIds` a partir dos vínculos canônicos estruturados das tarefas (`Task.executorIds` e `Task.executorPeriods.executorId`), enviando apenas os ~72 executores ativos e com tarefas no período.

### Otimização #2 — Paralelizar Consultas de Conflitos
- **Antes**: Executava `await cs.getConflictsForRange(...)` e logo após `await cs.getExecutionEventsForRange(...)` sequencialmente.
- **Depois**: Como as duas views (`v_conflict_por_dia_executor` e `v_conflict_execution_events`) são independentes, são disparadas simultaneamente via `Future.wait<dynamic>`, reduzindo o tempo de conflitos de **4.901 ms** para **982 ms** (**-80%**).

### Otimização #3 — Reuso de Tarefas Pré-carregadas (`widget.filteredTasks`)
- **Antes**: `TeamScheduleView` ignorava as tarefas passadas pelo componente pai (`main.dart` com `_tasksSemFiltros`) e executava uma query completa redundante `taskService.getTasksForRange` ao Supabase (~1.480 ms).
- **Depois**: Quando `widget.filteredTasks` está presente e populada, a tela reutiliza diretamente a lista da memória, eliminando 1 query pesada de tarefas e economizando 1.480 ms de rede.

### Otimização #4 — Paralelização de Metadados Independentes
- **Antes**: As chamadas `getAllTiposAtividade`, `getAllStatus`, `getEquipes...`, `getAllExecutores`, `getAllDivisoes` e `getCoordenadores` rodavam em cascata sequencial.
- **Depois**: Agrupadas em um único `Future.wait<dynamic>`, disparando todas as queries de metadados concorrentemente. Feriados continuam sendo carregados imediatamente após as tarefas, respeitando a dependência de IDs dos locais.

### Otimização #5 — Eliminação da Montagem Duplicada de Linhas
- **Antes**: `_buildExecutorRowsFromView` era chamado no final de `_loadBackendConflicts` e novamente logo em seguida no final de `_loadData`, processando 5.356 linhas da view e centenas de executores duas vezes consecutivas durante o boot da tela.
- **Depois**: `_loadBackendConflicts` aceita `bool rebuildRows = true`. Quando chamado pelo `_loadData`, passa `rebuildRows: false`, deixando a montagem das linhas ocorrer **uma única vez** no final do pipeline.

### Otimização #6 — Índice de Tarefas por ID (`tasksByIdIndex`)
- **Antes**: Para cada linha da view (5.356 registros) e para cada executor (414), o código realizava buscas lineares `for (final t in _tasks) if (t.id == taskId)`, totalizando **1.135.741 iterações**.
- **Depois**: Um mapa `Map<String, Task> tasksByIdIndex` é construído uma única vez em $O(T)$, transformando todas as buscas lineares em lookups diretos de complexidade $O(1)$. Total de buscas lineares: **0**.

### Otimização #7 — Índice de Tarefas por Executor UUID (`tasksByExecutorId`)
- **Antes**: No enriquecimento de cada executor, o código realizava uma varredura completa por todas as tarefas (`for (final task in _tasks)` com `isTaskAssignedToExecutor`), totalizando **249.228 avaliações** ($O(E \times T)$).
- **Depois**: Pré-indexação canônica `Map<String, List<Task>> tasksByExecutorId` por UUID estruturado em uma única passagem. O loop de cada executor avalia apenas as tarefas diretamente atribuídas a ele (0 a 10 tarefas). Total de chamadas a `isTaskAssignedToExecutor`: **0**.

---

## 3. VALIDAÇÃO DE SEGURANÇA E REGRESSÃO

- **Identidade Canônica**: Mantida 100% por UUID. Nenhuma verificação de homônimo ou matching operacional por nome/matrícula foi introduzida.
- **Regras de Negócio e Conflitos**: Idênticas. Filtro de equipe, filtros organizacionais e detecção local de fallback permanecem intactos.
- **Geometria do Gantt**: Intacta (`rowHeight`, largura de dias, escalas, scroll sync e drag/drop inalterados).
- **Realtime e TabSync**: Subscriptions e handlers intactos.
- **Banco de Dados**: 0 alterações no schema, 0 migrations, 0 alterações em views SQL.

---

## 4. RESULTADOS DOS TESTES DE QUALIDADE

- **Suíte de Testes Direcionados (`team_schedule`, `resource_schedule`, `conflict_detection`)**: **41 PASS / 0 FAIL**.
- **Suíte Global do Projeto (`flutter test`)**: **342 PASS / 0 FAIL**.
- **Análise Estática (`flutter analyze lib/`)**: **0 erros de compilação**.
