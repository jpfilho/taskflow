import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/services/task_service.dart';
import 'package:task2026/services/executor_service.dart';
import 'package:task2026/services/conflict_service.dart';
import 'package:task2026/services/status_service.dart';
import 'package:task2026/services/tipo_atividade_service.dart';
import 'package:task2026/services/equipe_service.dart';
import 'package:task2026/services/divisao_service.dart';
import 'package:task2026/services/feriado_service.dart';
import 'package:task2026/services/nota_sap_service.dart';
import 'package:task2026/services/ordem_service.dart';
import 'package:task2026/services/at_service.dart';
import 'package:task2026/services/si_service.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/widgets/team_schedule_view.dart';

void main() {
  test('TASKFLOW AUDIT: Atividades vs Team Schedule Performance Benchmark', () async {
    print('============================================================');
    print('TASKFLOW AUDIT: Atividades vs Team Schedule Performance Benchmark');
    print('============================================================');

    SharedPreferences.setMockInitialValues({});

    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
      );
    } catch (e) {
      fail('Falha ao inicializar Supabase: $e');
    }

    final taskService = TaskService();
    final executorService = ExecutorService();
    final conflictService = ConflictService();
    final statusService = StatusService();
    final tipoAtividadeService = TipoAtividadeService();
    final equipeService = EquipeService();
    final divisaoService = DivisaoService();
    final feriadoService = FeriadoService();
    final notaSapService = NotaSAPService();
    final ordemService = OrdemService();
    final atService = ATService();
    final siService = SIService();

    final startDate = DateTime(2026, 6, 1);
    final endDate = DateTime(2026, 6, 30);
    final daysCount = endDate.difference(startDate).inDays + 1;

    print('\n[CONFIG] Janela de análise: ${startDate.toIso8601String().substring(0, 10)} até ${endDate.toIso8601String().substring(0, 10)} ($daysCount dias)');

    // =========================================================================
    // PIPELINE ATIVIDADES
    // =========================================================================
    print('\n------------------------------------------------------------');
    print('AUDITORIA: PIPELINE ATIVIDADES');
    print('------------------------------------------------------------');

    final actTotalSw = Stopwatch()..start();
    int actQueriesCount = 0;

    // 1. Carga inicial de tarefas no main.dart
    final actTasksSw = Stopwatch()..start();
    actQueriesCount++;
    final actBaseTasks = await taskService.filterTasks(
      dataInicioMin: startDate,
      dataFimMax: endDate,
    );
    actTasksSw.stop();
    print('[ATIVIDADES] 1. filterTasks: ${actTasksSw.elapsedMilliseconds}ms (${actBaseTasks.length} tarefas)');

    // 2. Extração dos executores específicos das tarefas para filtro de conflitos
    final actExecutorIds = <String>{};
    for (final t in actBaseTasks) {
      for (final id in t.executorIds) {
        if (id.trim().isNotEmpty) actExecutorIds.add(id.trim());
      }
    }
    print('[ATIVIDADES] 2. Executores distintos nas tarefas ativas: ${actExecutorIds.length}');

    // 3. Inicialização e carregamentos em paralelo do ActivityGanttView
    final actMetaSw = Stopwatch()..start();
    actQueriesCount += 6; // status, tipos, feriados, SAP(3)
    final actTaskIds = actBaseTasks.map((t) => t.id).toList();
    final actLocalIds = actBaseTasks.expand((t) => t.localIds).toSet().toList();
    
    await Future.wait([
      statusService.getAllStatus(),
      tipoAtividadeService.getAllTiposAtividade(),
      feriadoService.getFeriadosMapByDateRangeAndLocais(startDate, endDate, actLocalIds),
      notaSapService.contarNotasPorTarefas(actTaskIds),
      ordemService.contarOrdensPorTarefas(actTaskIds),
      siService.contarSIsPorTarefas(actTaskIds),
    ]);
    actMetaSw.stop();
    print('[ATIVIDADES] 3. Metadata & SAP counts (paralelo via Future.wait): ${actMetaSw.elapsedMilliseconds}ms');

    // 4. Conflitos de backend no ActivityGanttView (em paralelo, filtrando apenas executores das tarefas)
    final actConflictSw = Stopwatch()..start();
    actQueriesCount += 3; // isBackendAvailable + getConflictsForRange + getExecutionEventsForRange
    final actOk = await conflictService.isBackendAvailable();
    Map<String, dynamic>? actConflicts;
    Map<String, dynamic>? actEvents;
    if (actOk) {
      final conflictResults = await Future.wait([
        conflictService.getConflictsForRange(startDate, endDate, executorIds: actExecutorIds.toList()),
        conflictService.getExecutionEventsForRange(startDate, endDate, executorIds: actExecutorIds.toList()),
      ]);
      actConflicts = conflictResults[0];
      actEvents = conflictResults[1];
    }
    actConflictSw.stop();
    print('[ATIVIDADES] 4. Conflitos filtrados em paralelo: ${actConflictSw.elapsedMilliseconds}ms (${actConflicts?.length ?? 0} conflitos)');

    // 5. Preparação dos dados em memória (Dart CPU)
    final actCpuSw = Stopwatch()..start();
    // Atividades não precisa varrer O(E x T) nem reconstruir tarefas, usa as tarefas diretamente
    actCpuSw.stop();
    actTotalSw.stop();

    print('[ATIVIDADES] 5. Processamento CPU Dart: ${actCpuSw.elapsedMilliseconds}ms');
    print('[ATIVIDADES] TOTAL PIPELINE: ${actTotalSw.elapsedMilliseconds}ms | Queries: $actQueriesCount');

    // =========================================================================
    // PIPELINE TEAM SCHEDULE
    // =========================================================================
    print('\n------------------------------------------------------------');
    print('AUDITORIA: PIPELINE TEAM SCHEDULE (TeamScheduleView)');
    print('------------------------------------------------------------');

    final teamTotalSw = Stopwatch()..start();
    int teamQueriesCount = 0;

    // 1. Tipos de atividade e status
    final teamMetaSw = Stopwatch()..start();
    teamQueriesCount += 2;
    final tiposAtiv = await tipoAtividadeService.getAllTiposAtividade();
    final statuses = await statusService.getAllStatus();
    teamMetaSw.stop();
    print('[TEAM SCHEDULE] 1. Metadata básica (sequencial): ${teamMetaSw.elapsedMilliseconds}ms');

    // 2. Equipes ativas
    final teamEquipeSw = Stopwatch()..start();
    teamQueriesCount++;
    final todasEquipes = await equipeService.getEquipesAtivas();
    teamEquipeSw.stop();
    print('[TEAM SCHEDULE] 2. Equipes ativas: ${teamEquipeSw.elapsedMilliseconds}ms (${todasEquipes.length} equipes)');

    // 3. getTasksForRange (busca redundante no banco, ignora filteredTasks passada por main.dart)
    final teamTasksSw = Stopwatch()..start();
    teamQueriesCount++;
    final teamTasks = await taskService.getTasksForRange(
      startDate: startDate,
      endDate: endDate,
      aplicarPerfil: false,
    );
    teamTasksSw.stop();
    print('[TEAM SCHEDULE] 3. getTasksForRange (query no banco): ${teamTasksSw.elapsedMilliseconds}ms (${teamTasks.length} tarefas)');

    // 3.1 Feriados por locais das tarefas
    final teamFeriadoSw = Stopwatch()..start();
    teamQueriesCount++;
    final teamLocalIds = teamTasks.expand((t) => t.localIds).toSet().toList();
    final feriadosMap = await feriadoService.getFeriadosMapByDateRangeAndLocais(startDate, endDate, teamLocalIds);
    teamFeriadoSw.stop();
    print('[TEAM SCHEDULE] 3.1 Feriados por locais: ${teamFeriadoSw.elapsedMilliseconds}ms');

    // 4. Executores (busca todos os executores cadastrados)
    final teamExecSw = Stopwatch()..start();
    teamQueriesCount++;
    final allExecutores = await executorService.getAllExecutores();
    final executoresAtivos = allExecutores.where((e) => e.ativo).toList();
    teamExecSw.stop();
    print('[TEAM SCHEDULE] 4. getAllExecutores: ${teamExecSw.elapsedMilliseconds}ms (${executoresAtivos.length} ativos de ${allExecutores.length})');

    // 5. Divisões e Coordenadores
    final teamDivCoordSw = Stopwatch()..start();
    teamQueriesCount += 2;
    final divisoes = await divisaoService.getAllDivisoes();
    final coordenadores = await executorService.getCoordenadores();
    teamDivCoordSw.stop();
    print('[TEAM SCHEDULE] 5. Divisões e Coordenadores: ${teamDivCoordSw.elapsedMilliseconds}ms');

    // 6. Conflitos de backend no TeamScheduleView (SEQUENCIAL e para TODOS os 420 executores!)
    final teamConflictSw = Stopwatch()..start();
    teamQueriesCount += 3;
    final teamOk = await conflictService.isBackendAvailable();
    Map<String, dynamic>? teamConflicts;
    Map<String, dynamic>? teamEvents;
    if (teamOk) {
      final allExecIds = executoresAtivos.map((e) => e.id).toList();
      teamConflicts = await conflictService.getConflictsForRange(startDate, endDate, executorIds: allExecIds);
      teamEvents = await conflictService.getExecutionEventsForRange(startDate, endDate, executorIds: allExecIds);
    }
    teamConflictSw.stop();
    print('[TEAM SCHEDULE] 6. Backend Conflicts (sequencial, 420 executores): ${teamConflictSw.elapsedMilliseconds}ms (${teamConflicts?.length ?? 0} conflitos)');

    // 7. Query pesada na view v_execucoes_dia_completa
    final teamViewQuerySw = Stopwatch()..start();
    teamQueriesCount++;
    final execRowsFromView = await taskService.getExecucoesDia(
      executorIds: executoresAtivos.map((e) => e.id).toList(),
      startDate: startDate,
      endDate: endDate,
    );
    teamViewQuerySw.stop();
    print('[TEAM SCHEDULE] 7. Query v_execucoes_dia_completa: ${teamViewQuerySw.elapsedMilliseconds}ms (${execRowsFromView.length} registros retornados)');

    // 8. Processamento CPU de _buildExecutorRowsFromView (Medição de complexidade O(E x T) e loops)
    final teamCpuSw = Stopwatch()..start();
    int isTaskAssignedCalls = 0;
    int taskLinearSearches = 0;

    bool isTaskAssignedToExecutor(Task task, Executor executor) {
      isTaskAssignedCalls++;
      final execId = executor.id.trim().toLowerCase();
      if (execId.isEmpty) return false;
      if (task.executorIds.any((id) => id.trim().toLowerCase() == execId)) return true;
      if (task.executorPeriods.any((ep) => ep.executorId.trim().toLowerCase() == execId)) return true;
      return false;
    }

    final byExecutor = <String, List<Map<String, dynamic>>>{};
    for (final r in execRowsFromView) {
      final execId = r['executor_id']?.toString() ?? '';
      if (execId.isNotEmpty) {
        byExecutor.putIfAbsent(execId, () => []).add(r);
      }
    }

    final executorRows = <ExecutorTaskRow>[];
    for (final executor in executoresAtivos) {
      final list = byExecutor[executor.id] ?? [];
      final tasksById = <String, Task>{};
      final taskDaysByTipo = <String, Map<String, List<DateTime>>>{};

      for (final r in list) {
        final taskId = r['task_id']?.toString() ?? '';
        if (taskId.isEmpty) continue;
        final dayStr = r['day']?.toString();
        if (dayStr == null) continue;
        final day = DateTime.parse(dayStr);
        final tipoPeriodo = (r['tipo_periodo']?.toString() ?? 'EXECUCAO').toUpperCase();

        taskDaysByTipo.putIfAbsent(taskId, () => {});
        taskDaysByTipo[taskId]!.putIfAbsent(tipoPeriodo, () => []).add(day);

        // Busca linear em _tasks
        Task? originalTask;
        for (final t in teamTasks) {
          taskLinearSearches++;
          if (t.id == taskId) {
            originalTask = t;
            break;
          }
        }

        tasksById[taskId] = originalTask ?? Task(
          id: taskId,
          status: (r['task_status'] ?? '').toString(),
          statusNome: '',
          regional: '',
          divisao: '',
          locais: const [],
          segmento: '',
          equipes: const [],
          tipo: (r['task_tipo'] ?? '').toString(),
          tarefa: (r['task_tarefa'] ?? '').toString(),
          executores: const [],
          executor: '',
          frota: '',
          coordenador: '',
          si: '',
          dataInicio: day,
          dataFim: day,
          ganttSegments: const [],
          executorPeriods: const [],
          frotaPeriods: const [],
          precisaSi: false,
          executorIds: const [],
          equipeIds: const [],
          frotaIds: const [],
          localIds: const [],
        );
      }

      // Loop de enriquecimento O(E x T)
      for (final task in teamTasks) {
        if (isTaskAssignedToExecutor(task, executor)) {
          tasksById.putIfAbsent(task.id, () => task);
        }
      }

      executorRows.add(ExecutorTaskRow(
        executor: executor,
        tasks: tasksById.values.toList(),
      ));
    }
    teamCpuSw.stop();
    print('[TEAM SCHEDULE] 8. Processamento CPU Dart (agrupamento + loops): ${teamCpuSw.elapsedMilliseconds}ms');
    print('[TEAM SCHEDULE]    → Chamadas a isTaskAssignedToExecutor: $isTaskAssignedCalls');
    print('[TEAM SCHEDULE]    → Buscas lineares t in _tasks: $taskLinearSearches');

    // 9. SAP Counts (chamado em paralelo mas adiciona 4 queries)
    final teamSapSw = Stopwatch()..start();
    teamQueriesCount += 4;
    final sapResults = await Future.wait([
      notaSapService.contarNotasPorTarefas(teamTasks.map((t) => t.id).toList()),
      ordemService.contarOrdensPorTarefas(teamTasks.map((t) => t.id).toList()),
      atService.contarATsPorTarefas(teamTasks.map((t) => t.id).toList()),
      siService.contarSIsPorTarefas(teamTasks.map((t) => t.id).toList()),
    ]);
    teamSapSw.stop();
    print('[TEAM SCHEDULE] 9. SAP counts: ${teamSapSw.elapsedMilliseconds}ms');

    teamTotalSw.stop();
    print('[TEAM SCHEDULE] TOTAL PIPELINE: ${teamTotalSw.elapsedMilliseconds}ms | Queries: $teamQueriesCount');

    print('\n============================================================');
    print('COMPARAÇÃO DIRETA DE TEMPOS');
    print('============================================================');
    print('Atividades Total:   ${actTotalSw.elapsedMilliseconds}ms');
    print('TeamSchedule Total: ${teamTotalSw.elapsedMilliseconds}ms');
    final ratio = teamTotalSw.elapsedMilliseconds / (actTotalSw.elapsedMilliseconds > 0 ? actTotalSw.elapsedMilliseconds : 1);
    print('Diferença de tempo: TeamSchedule demora ${ratio.toStringAsFixed(1)}x mais que Atividades');
    print('============================================================\n');
  });
}
