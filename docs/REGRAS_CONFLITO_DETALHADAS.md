# Regras de conflito de agenda — explicação detalhada

Este documento descreve **como** as regras de conflito estão implementadas no código (Tela de Atividades / Gantt e Tela de Equipes), em que ordem são aplicadas e quais funções e estruturas de dados estão envolvidas.

---

## Modelo lógico (conceito central)

A detecção de conflito é feita **após normalizar as tarefas em eventos diários de execução por executor**:

1. **Para cada executor e para cada dia:** gerar **eventos de execução** `(executor, dia, local, tarefa)` apenas se:
   - a tarefa **não** estiver cancelada ou reprogramada;
   - o executor estiver **alocado** à tarefa;
   - houver **EXECUÇÃO** nesse dia para esse executor, com prioridade: **executorPeriods da tarefa** → **executorPeriods do pai** → **filhos** → **ganttSegments**.
2. **Agrupar** os eventos por `(executor, dia)`.
3. **Existe conflito** se, no mesmo `(executor, dia)`, houver **dois ou mais locais distintos**.

A lógica é **única e reutilizável**, implementada em **`lib/utils/conflict_detection.dart`** (classe `ConflictDetection` e modelo `ExecutionEvent`). A **Tela de Atividades (Gantt)** e a **Tela de Equipes** usam essa mesma implementação, passando cada uma sua lista de tarefas.

---

## 1. Definição de conflito

**Conflito** = o **mesmo executor** tem atividade de **EXECUÇÃO** no **mesmo dia** em **mais de um local distinto**.

Consequências:

- **Um único local no dia** → nunca é conflito (mesmo que haja várias tarefas no mesmo local).
- **Dois ou mais locais no mesmo dia** → conflito (segmento fica vermelho e o tooltip explica).
- Apenas períodos do tipo **EXECUÇÃO** entram na conta; **PLANEJAMENTO** e **DESLOCAMENTO** são ignorados para conflito.

---

## 2. Onde está implementado

| Camada | Arquivo | Conteúdo |
|--------|---------|----------|
| **Lógica única** | `lib/utils/conflict_detection.dart` | `ExecutionEvent`, `ConflictDetection.isTaskExcludedFromConflict`, `taskHasExecutionOnDayForExecutor`, `getExecutionEventsForDay`, `hasConflictOnDayForExecutor`, `getConflictDescriptionsForDay` |
| **Tela de Atividades (Gantt)** | `lib/widgets/gantt_chart.dart` | Usa `ConflictDetection.hasConflictOnDayForExecutor(taskList, day, executorId)`, `getConflictDescriptionsForDay`, `taskHasExecutionOnDayForExecutor` (para dias de conflito por segmento), `getExecutorIdsForTask`; lista = `tasksForConflictDetection ?? tasks`. |
| **Tela de Equipes** | `lib/widgets/team_schedule_view.dart` | Usa `ConflictDetection.hasConflictOnDayForExecutor(_tasksForConflictDetection, day, executorId)` e `getConflictDescriptionsForDay`; lista = `_tasksForConflictDetection` (tarefas de todos os executores + `_tasks` para pai/enriquecimento). |

Ambas as telas delegam a detecção ao mesmo módulo; apenas a **lista de tarefas** passada difere (Gantt: lista do widget; Equipes: união das tarefas dos rows com `_tasks`).

**Backend (Supabase) — fonte principal dos conflitos:** Quando o Gantt ou a Tela de Equipes recebem `conflictService` (e a view existe no projeto), **toda** a detecção de conflitos e o conteúdo do tooltip vêm **exclusivamente** do Supabase: views `v_conflict_por_dia_executor` (has_conflict, descriptions por executor_id/dia) e `v_conflict_execution_events` (eventos por dia para as descrições). As mesmas regras (só EXECUÇÃO, status excluídos, prioridade executor_periods → pai → filhos → gantt_segments) estão na migration `supabase/migrations/20260217_conflict_execution_events_view.sql`. O frontend usa `ConflictService` para carregar o mapa de conflitos e os eventos; fallback para `ConflictDetection` em memória apenas se o backend não estiver disponível.

**Executores com o mesmo nome:** A view e o mapa de conflitos são chaveados por **executor_id** (UUID). No frontend, o conflito é mostrado **apenas** quando a tarefa tem **executor_id** (UUID) para esse executor (por exemplo em `executorPeriods` ou `executorIds`). Nomes que não puderem ser resolvidos a um UUID são ignorados na detecção de conflito, para nunca atribuir o conflito de uma pessoa a outra com o mesmo nome. Para que o conflito apareça corretamente, as tarefas devem vir com `executor_id` preenchido (ex.: via `executor_periods` ou `tasks_executores`).

---

## 3. Exclusão por status e tipo (tarefas que não entram na detecção)

Antes de qualquer lógica de período ou local, a tarefa é excluída da detecção de conflito se o **tipo** for ADMIN/REUNIAO ou se o **status** (código ou nome) indicar cancelamento ou reprogramação.

**Função:** `ConflictDetection.isTaskExcludedFromConflict(task)` (em `conflict_detection.dart`).

**Regras de tipo:** Excluir se `tipo` (maiúsculas, trim) for `ADMIN` ou `REUNIAO`.

**Regras de status:**

1. Se `status` e `statusNome` estiverem vazios → **não** excluir.
2. Excluir se o **código** for exatamente: `CANC`, `RPGR`, `REPR`, `RPAR`, `REPROGRAMADA`, `CANCELADA`, `CANCELADO`.
3. Excluir se o **nome** contiver: `CANCELAD`, `REPROGRAMAD`.
4. Excluir se o **código** contiver: `RPGR`, `REPR`, `CANC`.

Na view do backend (`v_conflict_execution_events`), a CTE `tarefas_incluidas` também exclui tarefas com tipo ADMIN ou REUNIAO (migration `20260218_conflict_exclude_tipo_admin_reuniao.sql`).

Tarefas excluídas não entram na contagem de “execução no dia” nem no tooltip de conflito.

---

## 4. Verificar se a tarefa “envolve” o executor

Para um dado **dia** e **executor** (id ou nome), só consideramos tarefas em que esse executor está alocado. Isso é feito por:

**Em ConflictDetection:** ao gerar eventos (`getExecutionEventsForDay`), para cada tarefa e cada executor da tarefa verifica-se `_taskInvolvesExecutor`:

- `task.executorIds.contains(executorId)` **ou**
- nome em `task.executor` (split por vírgula, normalizado) contém o executor **ou**
- `task.executores` contém o executor (normalizado) **ou**
- `task.executorPeriods` tem algum item que “bate” com o executor (por `executorId` ou `executorNome`).

**Normalização do executor:** `_normalizeExecutorKey(s)` — trim, minúsculas, remove acentos e caracteres não alfanuméricos, para comparar “EDMUNDO” com “Edmundo” ou “edmundo”.

Se a tarefa **não** envolve o executor, ela é ignorada para esse dia/executor.

---

## 5. Decidir se o executor tem EXECUÇÃO nesse dia (núcleo da regra)

Esta é a parte mais importante: **para essa tarefa, esse executor e esse dia**, o executor “tem execução” ou não? Só períodos com `tipoPeriodo == 'EXECUCAO'` contam.

A lógica segue uma **ordem fixa** em `ConflictDetection.taskHasExecutionOnDayForExecutor(task, executorId, dayStart, dayEnd, allTasks)`.

**Regra de ouro (evita falso conflito):** Se existir `executorPeriods` (na tarefa ou no pai) para este executor e **não** houver segmento EXECUCAO que intercepte o dia, **não** há execução — **nunca** cair em `ganttSegments`. O fallback para `ganttSegments` só vale quando **não** há nenhum `executorPeriods` aplicável para esse executor.

### 5.1 Tarefa tem `executorPeriods` (período específico por executor)

- Se `task.executorPeriods` **não** está vazio:
  - Procura um `ExecutorPeriod` que corresponda ao executor (por `executorId` ou `executorNome`, normalizado).
  - Dentro desse período, considera **somente** segmentos com `tipoPeriodo == 'EXECUCAO'`.
  - Se o dia (dayStart..dayEnd) **interceptar** algum desses segmentos de EXECUÇÃO → **tem execução** nesse dia.
  - Se houver período para o executor mas o dia não interceptar nenhum segmento de EXECUÇÃO → **não** tem execução.
  - Se não existir nenhum `ExecutorPeriod` para esse executor → segue para as regras abaixo (subtarefa / pai / ganttSegments).

Ou seja: **quando existe período específico por executor, só esse período é usado**; o período geral da tarefa (`ganttSegments`) **não** é usado para esse executor.

### 5.2 Subtarefa: período do pai

- Se a tarefa tem **parentId**:
  - O **pai** é buscado na lista de tarefas (no Gantt: `tasksForConflictDetection` ou `widget.tasks`; na Tela de Equipes: `_tasks`).
  - Se o pai existir e tiver **executorPeriods**:
    - Aplica a mesma lógica do item 5.1, mas usando os **executorPeriods do pai** para esse executor.
    - Se o dia interceptar um período de EXECUÇÃO do pai para esse executor → **tem execução**.
    - Caso contrário → **não** tem execução (e não se usa os ganttSegments da subtarefa para conflito nesse caso).

Assim, para subtarefas (ex.: “EDMUNDO - Retrofit CS 01K1”), o período considerado é o do **pai** quando o pai tem períodos por executor.

### 5.3 Tarefa pai sem `executorPeriods`: subtarefas desse executor

- Se a tarefa **não** tem `executorPeriods` (e não caiu em 5.1 nem em 5.2 por ser subtarefa com pai com período):
  - Se ela tem **filhos** (subtarefas) na lista:
    - Verifica se a tarefa “envolve” o executor (lista de executores da tarefa pai).
    - Para cada **filho** que envolva o executor, chama **recursivamente** a mesma função “tem execução nesse dia?”.
    - Se **algum** filho tiver execução nesse dia para esse executor → **tem execução**.
    - Se nenhum filho tiver → **não** tem execução.

Isso evita contar o período geral da tarefa pai quando existem subtarefas por executor e o pai não tem `executorPeriods`.

### 5.4 Sem período específico: usar os dias da tarefa (`ganttSegments`)

- Se após todos os passos acima ainda **não** tiver sido determinado “tem execução”:
  - Usa os **ganttSegments** da tarefa.
  - Considera **apenas** segmentos com `tipoPeriodo == 'EXECUCAO'`.
  - Se o dia interceptar algum desses segmentos → **tem execução** nesse dia.

Regra prática: **quando não há período específico por executor (nem na tarefa nem no pai), usam-se os dias da tarefa** em que ela está programada (ex.: Treinamento NR-35 com vários executores — todos no mesmo período da tarefa).

---

## 6. Chave de local (como “local” é identificado)

Para saber se há **mais de um local** no mesmo dia, precisamos de uma chave única por local:

**Função:** `ConflictDetection.taskLocationKey(task)` (usada ao montar cada `ExecutionEvent`).

**Ordem de uso:**

1. Se `task.localIds` não estiver vazio → `task.localIds.join('|')`.
2. Senão, se `task.localId` não for nulo/vazio → `task.localId`.
3. Senão, se `task.locais` não estiver vazio → `task.locais.join('|')`.
4. Senão (no Gantt) → `'task-${task.id}'` para não misturar tarefas sem local com outras.

Tarefas no **mesmo local** (mesma chave) são agrupadas; conflito só quando há **pelo menos duas chaves diferentes** no mesmo dia para o mesmo executor.

---

## 7. Algoritmo “há conflito neste dia para este executor?”

**Implementação única** (`ConflictDetection.hasConflictOnDayForExecutor(tasks, day, executorId)`):

1. Chama `getExecutionEventsForDay(tasks, day)` → lista de `ExecutionEvent` (executor, dia, locationKey, taskId, description).
2. Filtra os eventos pelo executor (por normalização de id/nome).
3. Obtém o **Set** de `locationKey` desses eventos.
4. **Conflito** ⇔ o Set tem **mais de um** elemento (dois ou mais locais distintos).

Tanto o **Gantt** quanto a **Tela de Equipes** chamam essa mesma função, passando a lista de tarefas adequada; o resultado e o tooltip (via `getConflictDescriptionsForDay`) ficam alinhados.

---

## 8. Quando o segmento fica vermelho e o tooltip

**No Gantt:**

- Para cada tarefa e cada segmento (barra) de EXECUÇÃO, o código obtém a faixa de datas do segmento e a lista de executores da tarefa (`_getExecutorIdsForTask`).
- Para cada dia nessa faixa e cada executor, verifica se **esse executor** tem execução nesse dia **nessa tarefa** (`_taskHasExecutionForExecutorOnDay`) e se **há conflito** nesse dia para esse executor (`_hasConflictOnDayForExecutor`).
- Os dias em que há conflito para pelo menos um executor da tarefa são reunidos em `_getConflictDaysForTask` → `conflictDays`.
- Se `conflictDays` não for vazio, o segmento pode ser pintado de vermelho nesses dias e o tooltip é montado em `_getConflictDetailsMessage`: lista de “Executor(es) em conflito” e “Motivo: mesmo executor alocado em mais de um local/tarefa nesses dias” com a lista de “LOCAL — Tarefa (Status: ...)” vinda de `_getConflictTaskDescriptionsForDay(day, execId, excludeTaskId: task.id)` para cada dia e cada executor em conflito.

**Na Tela de Equipes:**

- Para cada dia do período e cada executor, `_hasConflictOnDayForExecutor(day, executorId)` usa a mesma lista de descrições que o tooltip (`_getConflictTaskDescriptionsForDay`).
- O segmento fica vermelho quando há mais de um local nessa lista para aquele dia/executor; o tooltip usa a mesma lista para montar a mensagem.

---

## 9. Resumo em ordem de aplicação (por tarefa e por dia)

Para **cada** tarefa considerada para **um** executor e **um** dia:

1. **Excluir** se status for CANC/RPGR/REPR/RPAR/REPROGRAMADA/CANCELADA (ou variantes).
2. **Ignorar** se a tarefa não envolve esse executor (id, nome, executorPeriods).
3. **“Tem execução nesse dia?”** (apenas EXECUÇÃO):
   - Se a tarefa tem **executorPeriods** para o executor → usar **só** os períodos de EXECUÇÃO desse executor; dia conta se interceptar.
   - Se a tarefa é **subtarefa** e o **pai** tem executorPeriods para o executor → usar **só** o período do pai (EXECUÇÃO); dia conta se interceptar.
   - Se a tarefa é **pai** sem executorPeriods e tem **filhos** que envolvem o executor → dia conta se **algum filho** tiver execução nesse dia (recursivo).
   - **Senão** → usar **ganttSegments** de EXECUÇÃO da tarefa; dia conta se interceptar.
4. Se “tem execução” → obter a **chave de local** da tarefa e acrescentar ao conjunto de locais do dia/executor.
5. **Conflito** nesse dia para esse executor ⇔ o conjunto de locais tem **tamanho ≥ 2**.

---

## 10. Exemplos rápidos

- **Treinamento NR-35 (NEPTRFET), vários executores, sem executorPeriods:** os dias da tarefa vêm de `ganttSegments` (ex.: 17–20). EDMUNDO conta em NEPTRFET nesses dias; se no mesmo dia ele estiver em TSD (ex.: Retrofit) → dois locais → conflito (ex.: dias 19 e 20).
- **Retrofit CS 01K1 (TSD), com executorPeriods para EDMUNDO só 10–14 e 19–28:** no dia 07 só conta se houver execução no período de EDMUNDO; como o período dele não inclui 07, TSD não conta para EDMUNDO no dia 07 → sem conflito com BES nesse dia.
- **Tarefa cancelada (CANC):** excluída em 1 → não entra na contagem de locais nem no tooltip.

Esta é a lógica completa e detalhada das regras de conflito implementadas no código.
