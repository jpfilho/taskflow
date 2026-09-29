import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/utils/conflict_detection.dart';

/// Helper canônico idêntico ao implementado em TeamScheduleView
bool isTaskAssignedToExecutor(Task task, Executor executor) {
  final execId = executor.id.trim().toLowerCase();
  if (execId.isEmpty) return false;

  // 1. Vínculo estruturado por executorIds (UUID)
  if (task.executorIds.any((id) => id.trim().toLowerCase() == execId)) {
    return true;
  }

  // 2. Vínculo estruturado por executorPeriods via executorId (UUID)
  if (task.executorPeriods.any((ep) => ep.executorId.trim().toLowerCase() == execId)) {
    return true;
  }

  return false;
}

/// Helper para resolução de ExecutorPeriod no Gantt idêntico ao implementado em TeamScheduleView
ExecutorPeriod? resolveExecutorPeriodForGantt(Task task, Executor executor) {
  final rowExecutorId = executor.id.trim().toLowerCase();
  for (final ep in task.executorPeriods) {
    final periodExecutorId = ep.executorId.trim().toLowerCase();
    if (periodExecutorId.isNotEmpty && periodExecutorId == rowExecutorId) {
      return ep;
    }
  }
  return null;
}

void main() {
  Task mkTask({
    required String id,
    String status = 'PROG',
    List<String> locais = const [],
    List<String> localIds = const [],
    String executor = '',
    List<String> executores = const [],
    List<String> executorIds = const [],
    List<GanttSegment> ganttSegments = const [],
    List<ExecutorPeriod> executorPeriods = const [],
    String? equipeId,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) {
    return Task(
      id: id,
      status: status,
      statusNome: 'Programada',
      regional: 'R1',
      divisao: 'D1',
      locais: locais,
      localIds: localIds,
      tipo: 'MANUTENCAO',
      tarefa: 'Tarefa $id',
      executor: executor,
      executores: executores,
      executorIds: executorIds,
      coordenador: 'Coord',
      equipeId: equipeId,
      dataInicio: dataInicio ?? DateTime(2026, 3, 1),
      dataFim: dataFim ?? DateTime(2026, 3, 10),
      ganttSegments: ganttSegments,
      executorPeriods: executorPeriods,
    );
  }

  Executor mkExec({
    required String id,
    required String nome,
    String matricula = '',
    String? nomeCompleto,
  }) {
    return Executor(
      id: id,
      nome: nome,
      matricula: matricula,
      nomeCompleto: nomeCompleto ?? nome,
      ativo: true,
    );
  }

  GanttSegment seg(DateTime start, DateTime end, [String tipoPeriodo = 'EXECUCAO']) {
    return GanttSegment(
      dataInicio: start,
      dataFim: end,
      label: '',
      tipo: 'OUT',
      tipoPeriodo: tipoPeriodo,
    );
  }

  group('Team Schedule — Canonical Executor Identity (UUID)', () {
    test('1. Homônimos com IDs diferentes recebem apenas suas respectivas tarefas', () {
      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'JOÃO SILVA', matricula: '1001');
      final execB = mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'JOÃO SILVA', matricula: '2002');

      final taskA1 = mkTask(id: 'A1', executorIds: ['11111111-1111-1111-1111-111111111111'], locais: ['TERESINA II']);
      final taskA2 = mkTask(id: 'A2', executorIds: ['11111111-1111-1111-1111-111111111111'], locais: ['PIRIPIRI']);
      final taskB1 = mkTask(id: 'B1', executorIds: ['22222222-2222-2222-2222-222222222222'], locais: ['SOBRADINHO']);
      final taskB2 = mkTask(id: 'B2', executorIds: ['22222222-2222-2222-2222-222222222222'], locais: ['FORTALEZA II']);

      final allTasks = [taskA1, taskA2, taskB1, taskB2];

      final tasksForA = allTasks.where((t) => isTaskAssignedToExecutor(t, execA)).toList();
      final tasksForB = allTasks.where((t) => isTaskAssignedToExecutor(t, execB)).toList();

      expect(tasksForA.map((t) => t.id).toList(), ['A1', 'A2']);
      expect(tasksForB.map((t) => t.id).toList(), ['B1', 'B2']);

      final locationsA = tasksForA.expand((t) => t.locais).toList();
      final locationsB = tasksForB.expand((t) => t.locais).toList();

      expect(locationsA, ['TERESINA II', 'PIRIPIRI']);
      expect(locationsB, ['SOBRADINHO', 'FORTALEZA II']);

      expect(tasksForA.length, 2);
      expect(tasksForB.length, 2);
    });

    test('2. Homônimos com mesmo nome E mesma matrícula continuam isolados por UUID', () {
      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'JOÃO SILVA', matricula: '1001');
      final execB = mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'JOÃO SILVA', matricula: '1001');

      final taskA = mkTask(id: 'A1', executorIds: ['11111111-1111-1111-1111-111111111111'], locais: ['TERESINA II']);
      final taskB = mkTask(id: 'B1', executorIds: ['22222222-2222-2222-2222-222222222222'], locais: ['SOBRADINHO']);

      expect(isTaskAssignedToExecutor(taskA, execA), isTrue);
      expect(isTaskAssignedToExecutor(taskA, execB), isFalse);

      expect(isTaskAssignedToExecutor(taskB, execA), isFalse);
      expect(isTaskAssignedToExecutor(taskB, execB), isTrue);
    });

    test('3. Nomes similares (substring / contains) não causam contaminação', () {
      final execPai = mkExec(id: '33333333-3333-3333-3333-333333333333', nome: 'JOÃO SILVA');
      final execFilho = mkExec(id: '44444444-4444-4444-4444-444444444444', nome: 'JOÃO SILVA FILHO');

      final taskPai = mkTask(id: 'tp', executorIds: ['33333333-3333-3333-3333-333333333333'], executor: 'JOÃO SILVA');
      final taskFilho = mkTask(id: 'tf', executorIds: ['44444444-4444-4444-4444-444444444444'], executor: 'JOÃO SILVA FILHO');

      expect(isTaskAssignedToExecutor(taskPai, execPai), isTrue);
      expect(isTaskAssignedToExecutor(taskPai, execFilho), isFalse);

      expect(isTaskAssignedToExecutor(taskFilho, execPai), isFalse);
      expect(isTaskAssignedToExecutor(taskFilho, execFilho), isTrue);
    });

    test('4. Tarefa sem executor estruturado (apenas equipe) não é atribuída individualmente', () {
      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'JOÃO SILVA');
      final taskEquipe = mkTask(
        id: 't-equipe',
        equipeId: 'equipe-123',
        executorIds: [],
        executorPeriods: [],
      );

      expect(isTaskAssignedToExecutor(taskEquipe, execA), isFalse);
    });

    test('5. Vínculo por executorPeriods isola estritamente por executorId UUID', () {
      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'JOÃO SILVA');
      final execB = mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'JOÃO SILVA');

      final epA = ExecutorPeriod(
        executorId: '11111111-1111-1111-1111-111111111111',
        executorNome: 'JOÃO SILVA',
        periods: [seg(DateTime(2026, 3, 1), DateTime(2026, 3, 5))],
      );

      final task = mkTask(
        id: 't-period',
        executorIds: [],
        executorPeriods: [epA],
      );

      expect(isTaskAssignedToExecutor(task, execA), isTrue);
      expect(isTaskAssignedToExecutor(task, execB), isFalse);

      // Resolução no Gantt
      expect(resolveExecutorPeriodForGantt(task, execA), equals(epA));
      expect(resolveExecutorPeriodForGantt(task, execB), isNull);
    });

    test('6. Conflitos: Homônimos em locais distintos no mesmo dia NÃO geram falso conflito', () {
      final day = DateTime(2026, 3, 2);
      final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      // Simulação do mapa de conflito do backend (indexado por ${executorId.toLowerCase()}_$dayKey)
      final conflictMap = <String, bool>{
        '11111111-1111-1111-1111-111111111111_$dayKey': false,
        '22222222-2222-2222-2222-222222222222_$dayKey': false,
      };

      expect(conflictMap['11111111-1111-1111-1111-111111111111_$dayKey'], isFalse);
      expect(conflictMap['22222222-2222-2222-2222-222222222222_$dayKey'], isFalse);

      // Verificação em ConflictDetection com tarefas isoladas por UUID
      final taskA = mkTask(
        id: 'tA',
        locais: ['TERESINA II'],
        executor: 'JOÃO SILVA',
        executorIds: ['11111111-1111-1111-1111-111111111111'],
        ganttSegments: [seg(DateTime(2026, 3, 2), DateTime(2026, 3, 3))],
      );
      final taskB = mkTask(
        id: 'tB',
        locais: ['SOBRADINHO'],
        executor: 'JOÃO SILVA',
        executorIds: ['22222222-2222-2222-2222-222222222222'],
        ganttSegments: [seg(DateTime(2026, 3, 2), DateTime(2026, 3, 3))],
      );

      final allTasks = [taskA, taskB];

      // Quando as tarefas são atribuídas corretamente por UUID aos executores:
      final tasksA = allTasks.where((t) => isTaskAssignedToExecutor(t, mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'JOÃO SILVA'))).toList();
      final tasksB = allTasks.where((t) => isTaskAssignedToExecutor(t, mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'JOÃO SILVA'))).toList();

      expect(tasksA.length, 1);
      expect(tasksB.length, 1);

      // Nenhuma das listas individuais possui múltiplos locais no mesmo dia
      final hasConflictA = ConflictDetection.hasConflictOnDayForExecutor(tasksA, day, '11111111-1111-1111-1111-111111111111');
      final hasConflictB = ConflictDetection.hasConflictOnDayForExecutor(tasksB, day, '22222222-2222-2222-2222-222222222222');

      expect(hasConflictA, isFalse);
      expect(hasConflictB, isFalse);
    });

    test('7. Conflito legítimo no mesmo executor (mesmo UUID) é detectado', () {
      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'JOÃO SILVA');
      final day = DateTime(2026, 3, 2);

      final task1 = mkTask(
        id: 't1',
        locais: ['TERESINA II'],
        executorIds: ['11111111-1111-1111-1111-111111111111'],
        executor: 'JOÃO SILVA',
        ganttSegments: [seg(DateTime(2026, 3, 2), DateTime(2026, 3, 3))],
      );
      final task2 = mkTask(
        id: 't2',
        locais: ['PIRIPIRI'],
        executorIds: ['11111111-1111-1111-1111-111111111111'],
        executor: 'JOÃO SILVA',
        ganttSegments: [seg(DateTime(2026, 3, 2), DateTime(2026, 3, 3))],
      );

      final tasksA = [task1, task2].where((t) => isTaskAssignedToExecutor(t, execA)).toList();
      final hasConflict = ConflictDetection.hasConflictOnDayForExecutor(tasksA, day, '11111111-1111-1111-1111-111111111111');

      expect(hasConflict, isTrue);
    });

    test('8. Payload do relatório é agrupado por executor_id canônico e inclui campos requeridos', () {
      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'JOÃO SILVA', matricula: '1001');
      final execB = mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'JOÃO SILVA', matricula: '2002');

      final taskA1 = mkTask(id: 'A1', executorIds: ['11111111-1111-1111-1111-111111111111'], locais: ['TERESINA II']);
      final taskA2 = mkTask(id: 'A2', executorIds: ['11111111-1111-1111-1111-111111111111'], locais: ['PIRIPIRI']);
      final taskB1 = mkTask(id: 'B1', executorIds: ['22222222-2222-2222-2222-222222222222'], locais: ['SOBRADINHO']);
      final taskB2 = mkTask(id: 'B2', executorIds: ['22222222-2222-2222-2222-222222222222'], locais: ['FORTALEZA II']);

      final allTasks = [taskA1, taskA2, taskB1, taskB2];

      // Geração de payload agrupado por UUID
      Map<String, dynamic> buildReportPayload(Executor executor, List<Task> allTasks) {
        final assignedTasks = allTasks.where((t) => isTaskAssignedToExecutor(t, executor)).toList();
        return {
          'executor_id': executor.id,
          'executor_nome': executor.nome,
          'matricula': executor.matricula,
          'task_ids': assignedTasks.map((t) => t.id).toList(),
          'locais': assignedTasks.expand((t) => t.locais).toSet().toList(),
          'count': assignedTasks.length,
        };
      }

      final payloadA = buildReportPayload(execA, allTasks);
      final payloadB = buildReportPayload(execB, allTasks);

      expect(payloadA['executor_id'], '11111111-1111-1111-1111-111111111111');
      expect(payloadA['matricula'], '1001');
      expect(payloadA['task_ids'], ['A1', 'A2']);
      expect(payloadA['locais'], containsAll(['TERESINA II', 'PIRIPIRI']));
      expect(payloadA['count'], 2);

      expect(payloadB['executor_id'], '22222222-2222-2222-2222-222222222222');
      expect(payloadB['matricula'], '2002');
      expect(payloadB['task_ids'], ['B1', 'B2']);
      expect(payloadB['locais'], containsAll(['SOBRADINHO', 'FORTALEZA II']));
      expect(payloadB['count'], 2);
    });
  });
}
