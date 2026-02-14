# Análise: conflito de agenda (tela de atividades e tela de equipes)

## Regras unificadas (mesmas nas duas telas)

As **mesmas regras** para detectar conflito valem na **tela de atividades** (Gantt) e na **tela de equipes**:

| Regra | Descrição |
|-------|-----------|
| **Definição de conflito** | Mesmo executor com atividade de **EXECUÇÃO** no **mesmo dia** em **mais de um local distinto**. |
| **Só EXECUÇÃO** | Apenas períodos `tipoPeriodo == 'EXECUCAO'` entram na conta. PLANEJAMENTO e DESLOCAMENTO **não** geram conflito. |
| **Período por executor** | **Quando a tarefa tem período específico por executor (executorPeriods), o período que deve ser considerado para conflito é o período específico desse executor.** O período geral da tarefa (ganttSegments) não é usado nesse caso — ex.: EDMUNDO na TSD só a partir da 2ª semana. |
| **Subtarefa** | Se a tarefa é subtarefa (tem **parentId**) e o **pai** tem executorPeriods para esse executor, usar **só o período do pai** para esse executor — não usar os ganttSegments da subtarefa. Assim evita conflito quando o executor está só em parte do período da tarefa (ex.: EDMUNDO no Retrofit TSD só a partir de 10/02). |
| **Sem período específico por executor** | Se a tarefa **não** tem executorPeriods (ou não tem período para esse executor), **usar os dias da tarefa** em que ele está programado: os **ganttSegments** de EXECUÇÃO. O dia conta para o executor se estiver nesses segmentos — ex.: Treinamento NR-35 com vários executores: conta NEPTRFET nos dias da tarefa e pode gerar conflito com TSD nos dias 19–20. |
| **Dados** | Para o período por executor valer (ex.: EDMUNDO em TSD só a partir do dia 8), é preciso **salvar** os períodos na tarefa e ter **executorPeriods** carregados (API); ideal persistir no cache local. |
| **Exclusão por status** | Tarefas **CANC**, **RPGR**, **REPR**, **RPAR**, **REPROGRAMADA**, **CANCELADA** (e variantes) **não** entram na detecção nem no tooltip. |
| **Um local = sem conflito** | Um único local no dia nunca é conflito; conflito só quando há **2 ou mais locais** com execução no mesmo dia. |

Implementação:
- **Tela de equipes:** `team_schedule_view.dart` — `_hasConflictOnDayForExecutor`, `_getConflictTaskDescriptionsForDay`, `_isTaskExcludedFromConflict`; tarefas enriquecidas com `executorPeriods` e status de `_tasks`.
- **Tela de atividades:** `gantt_chart.dart` — `_hasConflictOnDayForExecutor`, `_taskHasExecutionOnDayForExecutor` / `_taskHasExecutionForExecutorOnDay`, `_isTaskExcludedFromConflict`; usa `tasksForConflictDetection ?? tasks` (em `main.dart` passa `_tasksSemFiltros` ou fallback `_tasks` para nunca ser null); para linhas virtuais (por executor), busca o pai em `taskList` ou em `widget.tasks` para usar `executorPeriods` do pai.

---

## Regra principal de conflito

> **Conflito** = mesmo executor com **atividade de EXECUÇÃO** programada no **mesmo dia** em **locais diferentes**.

Ou seja: vermelho só quando há **mais de um local distinto** no mesmo dia para o mesmo executor, considerando **apenas** períodos do tipo **EXECUÇÃO** (PLANEJAMENTO e DESLOCAMENTO não geram conflito).

---

## Fluxo na tela de equipes

### 1. Origem dos dados

- A tela usa a view **`v_execucoes_dia_completa`** (ou MV) via `task_service.getExecucoesDia(...)`.
- A view retorna uma linha por (executor, task_id, day, tipo_periodo, local).
- Cada linha traz: `task_status`, `local_nome`, `loc_key`, `tipo_periodo`, `has_conflict`.

### 2. Construção das tarefas por executor

- Em `_buildExecutorRowsFromView`, para cada executor as linhas são agrupadas por `task_id`.
- Com **`putIfAbsent(taskId, () => Task(...))`** só a **primeira** linha de cada `task_id` define o `Task` (status, locais, etc.).
- Ou seja: se a mesma tarefa aparecer em várias linhas (vários dias ou vários locais), **status e locais** ficam os da primeira linha.
- Os dias são agregados em `taskDaysByTipo` e depois viram **segmentos** (`ganttSegments`) por tipo (EXECUÇÃO, PLANEJAMENTO, DESLOCAMENTO).

### 3. Quando o segmento fica vermelho

- Para **cada dia** do período visível, a tela chama **`_hasConflictOnDayForExecutor(day, executorId)`**.
- Essa função **não** usa o `has_conflict` da view; ela **recalcula** o conflito no app.

Lógica de **`_hasConflictOnDayForExecutor`** (alinhada ao Gantt):

1. Chama **`_getConflictTaskDescriptionsForDay(day, executorId)`** (mesma lista usada no tooltip).
2. Para cada tarefa em `row.tasks`: exclui por **`_isTaskExcludedFromConflict`**; se a tarefa tem **executorPeriods** para o executor, só considera o dia se estiver no período de EXECUÇÃO; senão usa **ganttSegments** de EXECUÇÃO.
3. Extrai **locais distintos** (parte antes de `" — "` nas descrições) e **conflito** ⇔ **mais de um local** nesse conjunto.

Ou seja: o segmento fica vermelho quando, para aquele executor e dia, existe execução em **mais de um local distinto**.

### 4. Tooltip de conflito

- Para cada segmento, são calculados os **dias em conflito** (`conflictDays`) com a mesma função `_hasConflictOnDayForExecutor`.
- A mensagem do tooltip é montada em **`_getConflictDetailsMessageForSegment`** → **`_getConflictTaskDescriptionsForDay`**, que lista “LOCAL — Tarefa” **excluindo** tarefas com **`_isTaskExcludedFromConflict`**.

---

## Por que pode dar vermelho “errado” (ex.: só um local ativo; o outro reprogramado)

Cenário típico:

- Executor (ex.: FCO WILSON) tem no mesmo dia:
  - uma tarefa no local **PRI** (ativa),
  - outra no local **NEPTRFET** (reprogramada).
- O esperado: **não** é conflito, pois só há um local “ativo”; o outro é reprogramado.

Isso só fica correto se a tarefa **reprogramada** for **excluída** da contagem de locais e do tooltip.

### Onde a exclusão acontece

- **`_isTaskExcludedFromConflict(task)`** em `team_schedule_view.dart` (e equivalente no `gantt_chart.dart`):
  - Exclui por **código**: `CANC`, `REPR`, `RPAR`, `REPROGRAMADA`, `CANCELADA`, `CANCELADO`.
  - Exclui por **nome**: `statusNome` contendo “CANCELAD” ou “REPROGRAMAD”.
  - Exclui se **`task.status`** contiver “REPR” ou “CANC”.

Se o banco gravar, por exemplo, **“Reprogramada”** em `tasks.status` (e não “REPR”):

- A **view** usa `UPPER(TRIM(...)) NOT IN ('CANC', 'REPR')` → **“REPROGRAMADA” não é filtrada** → a tarefa NEPTRFET **entra** na view e aparece na tela.
- No app, ao montar o `Task`, **`task.status`** fica **“Reprogramada”** (ou “REPROGRAMADA”).
- Com o helper atual, **`cod == 'REPROGRAMADA'`** e **`cod.contains('REPR')`** fazem essa tarefa ser excluída na contagem de locais e no tooltip → **um único local ativo** → **sem conflito** e **sem vermelho** nesse caso.

Se o status no banco for outro (ex.: sigla diferente ou texto em outro idioma), é preciso incluir esse valor no helper (código ou nome) para manter a mesma regra.

### View vs app

- A **view** hoje só exclui **`CANC`** e **`REPR`**. Se no banco existir **“Reprogramada”**, **“RPAR”**, **“Cancelada”**, etc., essas linhas **continuam** na view e os segmentos **continuam** a aparecer.
- O **app** já trata várias variantes em **`_isTaskExcludedFromConflict`**, então a **decisão de conflito** (vermelho sim/não) e o **conteúdo do tooltip** ficam corretos mesmo quando a view ainda traz a tarefa.
- Para evitar até mesmo **exibir** segmentos de tarefas reprogramadas/canceladas, a view pode ser estendida para excluir também **REPROGRAMADA**, **RPAR**, **CANCELADA** (ver sugestão no SQL abaixo).

---

## Resumo do fluxo “segmento vermelho”

| Etapa | O quê |
|-------|--------|
| Dados | View `v_execucoes_dia_completa` (ou MV); uma linha por (executor, task, day, tipo, local). |
| Task por id | Primeira linha do `task_id` define `Task` (status, locais). |
| Conflito no dia | Recalculado no app: só EXECUÇÃO; só locais de tarefas **não** excluídas por **`_isTaskExcludedFromConflict`**; conflito ⇔ mais de um local no dia. |
| Vermelho | Célula do dia e segmento ficam vermelhos quando **`_hasConflictOnDayForExecutor(day, executorId)`** é true. |
| Tooltip | Lista “LOCAL — Tarefa” só de tarefas **não** excluídas no mesmo dia. |

Garantir que tarefas reprogramadas/canceladas estejam cobertas por **`_isTaskExcludedFromConflict`** (e, opcionalmente, pela view) evita vermelho quando “só tem um local; o outro está reprogramado”.

---

## O que fazer na prática

1. **App (já feito)**  
   O helper **`_isTaskExcludedFromConflict`** em `team_schedule_view.dart` e `gantt_chart.dart` já considera:  
   `CANC`, `REPR`, `RPAR`, `REPROGRAMADA`, `CANCELADA`, `CANCELADO` e nomes que contenham “reprogramad”/“cancelad”.  
   Faça **hot restart** para carregar a alteração.

2. **View (opcional, recomendado)**  
   O script **`criar_view_execucoes_completa_otimizada.sql`** foi atualizado para excluir também **RPAR**, **RPGR**, **REPROGRAMADA**, **CANCELADA**, **CANCELADO** na view.  
   Reexecute o script da view no Supabase quando quiser que a exclusão seja feita já na consulta.

3. **Tela de Atividades (Gantt) vs Tela de Equipes**  
   A detecção de conflito é a mesma regra nas duas telas (mais de um local com EXECUÇÃO no mesmo dia para o mesmo executor). Para a tela de atividades mostrar o mesmo conflito que a de equipes:
   - O Gantt usa **`tasksForConflictDetection`** (em geral `_tasksSemFiltros`): a lista deve conter **todas** as tarefas relevantes (sem filtrar por executor), com **executorPeriods** carregados quando houver período específico por executor.
   - Foi adicionada **normalização de executor** no Gantt (`_normalizeExecutorKey`, `_executorPeriodMatches` e checagens `involvesExecutor`), alinhada à tela de equipes, para que nomes como "EDMUNDO" / "Edmundo" e períodos por executor sejam reconhecidos corretamente.
   - O tooltip de conflito no Gantt também exibe o **status** de cada tarefa listada (Status: PROG, RPGR, etc.).
