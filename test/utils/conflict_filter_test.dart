import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/services/conflict_service.dart';
import 'package:task2026/utils/conflict_detection.dart';

void main() {
  Task mkTask({
    required String id,
    String status = 'PROG',
    List<String> locais = const ['LOCAL_A'],
    List<String> localIds = const [],
    String? localId,
    String executor = '',
    List<String> executores = const [],
    List<String> executorIds = const [],
    List<GanttSegment> ganttSegments = const [],
    List<ExecutorPeriod> executorPeriods = const [],
    String? parentId,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) {
    return Task(
      id: id,
      status: status,
      statusNome: '',
      regional: 'R',
      divisao: 'D',
      locais: locais,
      localIds: localIds,
      localId: localId,
      tipo: 'T',
      tarefa: 'Tarefa $id',
      executor: executor,
      executores: executores.isEmpty ? (executor.isNotEmpty ? [executor] : []) : executores,
      executorIds: executorIds,
      coordenador: 'C',
      dataInicio: dataInicio ?? DateTime(2026, 3, 1),
      dataFim: dataFim ?? DateTime(2026, 3, 31),
      ganttSegments: ganttSegments,
      executorPeriods: executorPeriods,
      parentId: parentId,
    );
  }

  GanttSegment seg(DateTime start, DateTime end, [String tipoPeriodo = 'EXECUCAO']) {
    return GanttSegment(
      dataInicio: start,
      dataFim: end,
      label: 'EXEC',
      tipo: 'OUT',
      tipoPeriodo: tipoPeriodo,
    );
  }

  group('resolveConflictTaskIds & Filtro de Conflitos', () {
    final day10 = DateTime(2026, 3, 10);
    final day11 = DateTime(2026, 3, 11);

    test('34a & 38) Executor por UUID exato: 2 tasks conflitantes no mesmo dia retornam {A, B}', () {
      final taskA = mkTask(
        id: 'taskA',
        locais: ['LOC_1'],
        executorIds: ['uuid-1111-aaaa'],
        ganttSegments: [seg(DateTime(2026, 3, 5), DateTime(2026, 3, 15))],
      );
      final taskB = mkTask(
        id: 'taskB',
        locais: ['LOC_2'],
        executorIds: ['uuid-1111-aaaa'],
        ganttSegments: [seg(DateTime(2026, 3, 8), DateTime(2026, 3, 18))],
      );

      final result = ConflictDetection.resolveConflictTaskIds(
        task: taskA,
        day: day10,
        allTasks: [taskA, taskB],
      );

      expect(result, containsAll(['taskA', 'taskB']));
      expect(result.length, equals(2));
    });

    test('34b) Executor por UUID com caixa diferente (case-insensitive)', () {
      final taskA = mkTask(
        id: 'taskA',
        locais: ['LOC_1'],
        executorIds: ['UUID-ABC-123'],
        ganttSegments: [seg(DateTime(2026, 3, 5), DateTime(2026, 3, 15))],
      );
      final taskB = mkTask(
        id: 'taskB',
        locais: ['LOC_2'],
        executorIds: ['uuid-abc-123'], // Caixa baixa
        ganttSegments: [seg(DateTime(2026, 3, 8), DateTime(2026, 3, 18))],
      );

      final result = ConflictDetection.resolveConflictTaskIds(
        task: taskA,
        day: day10,
        allTasks: [taskA, taskB],
      );

      expect(result, containsAll(['taskA', 'taskB']));
    });

    test('34c & 34d) Executor sem UUID: fallback controlado por nome normalizado', () {
      final taskA = mkTask(
        id: 'taskA',
        locais: ['LOC_1'],
        executor: 'João da Silva',
        ganttSegments: [seg(DateTime(2026, 3, 5), DateTime(2026, 3, 15))],
      );
      final taskB = mkTask(
        id: 'taskB',
        locais: ['LOC_2'],
        executor: 'JOAO DA SILVA', // Variação de acento e caixa
        ganttSegments: [seg(DateTime(2026, 3, 8), DateTime(2026, 3, 18))],
      );

      final result = ConflictDetection.resolveConflictTaskIds(
        task: taskA,
        day: day10,
        allTasks: [taskA, taskB],
      );

      expect(result, containsAll(['taskA', 'taskB']));
    });

    test('35) Homônimos com IDs diferentes NUNCA colidem apenas por nome', () {
      // Dois executores chamados "Carlos Santos", mas com IDs distintos
      final taskA = mkTask(
        id: 'taskA',
        locais: ['LOC_1'],
        executor: 'Carlos Santos',
        executorIds: ['id-carlos-1'],
        ganttSegments: [seg(DateTime(2026, 3, 5), DateTime(2026, 3, 15))],
      );
      final taskB = mkTask(
        id: 'taskB',
        locais: ['LOC_2'],
        executor: 'Carlos Santos',
        executorIds: ['id-carlos-2'], // ID DIFERENTE!
        ganttSegments: [seg(DateTime(2026, 3, 8), DateTime(2026, 3, 18))],
      );

      final result = ConflictDetection.resolveConflictTaskIds(
        task: taskA,
        day: day10,
        allTasks: [taskA, taskB],
      );

      // Como os IDs são diferentes, NÃO há conflito para id-carlos-1
      expect(result.isEmpty, isTrue);
    });

    test('36) Sem conflito confirmado: retorna conjunto vazio (não inventa conflito)', () {
      final taskA = mkTask(
        id: 'taskA',
        locais: ['LOC_1'],
        executorIds: ['uuid-single'],
        ganttSegments: [seg(DateTime(2026, 3, 5), DateTime(2026, 3, 15))],
      );
      // Nenhuma outra tarefa no mesmo dia/executor
      final result = ConflictDetection.resolveConflictTaskIds(
        task: taskA,
        day: day10,
        allTasks: [taskA],
      );

      expect(result, isEmpty);
      expect(result, isA<Set<String>>());
    });

    test('37 & 39) 3 Tasks colidindo no mesmo período: resultado contém {A, B, C}', () {
      final taskA = mkTask(
        id: 'taskA',
        locais: ['LOC_1'],
        executorIds: ['uuid-shared'],
        ganttSegments: [seg(DateTime(2026, 3, 5), DateTime(2026, 3, 15))],
      );
      final taskB = mkTask(
        id: 'taskB',
        locais: ['LOC_2'],
        executorIds: ['uuid-shared'],
        ganttSegments: [seg(DateTime(2026, 3, 8), DateTime(2026, 3, 18))],
      );
      final taskC = mkTask(
        id: 'taskC',
        locais: ['LOC_3'],
        executorIds: ['uuid-shared'],
        ganttSegments: [seg(DateTime(2026, 3, 10), DateTime(2026, 3, 12))],
      );

      final result = ConflictDetection.resolveConflictTaskIds(
        task: taskA,
        day: day10,
        allTasks: [taskA, taskB, taskC],
      );

      expect(result, containsAll(['taskA', 'taskB', 'taskC']));
      expect(result.length, equals(3));
    });

    test('40) Tarefa em dia diferente não é agrupada no filtro', () {
      final taskA = mkTask(
        id: 'taskA',
        locais: ['LOC_1'],
        executorIds: ['uuid-shared'],
        ganttSegments: [seg(DateTime(2026, 3, 10), DateTime(2026, 3, 10, 23, 59, 59))], // Apenas dia 10
      );
      final taskB = mkTask(
        id: 'taskB',
        locais: ['LOC_2'],
        executorIds: ['uuid-shared'],
        ganttSegments: [seg(DateTime(2026, 3, 11), DateTime(2026, 3, 11, 23, 59, 59))], // Apenas dia 11
      );

      // No dia 10, apenas taskA executa
      final resultDay10 = ConflictDetection.resolveConflictTaskIds(
        task: taskA,
        day: day10,
        allTasks: [taskA, taskB],
      );
      expect(resultDay10, isEmpty);

      // No dia 11, apenas taskB executa
      final resultDay11 = ConflictDetection.resolveConflictTaskIds(
        task: taskB,
        day: day11,
        allTasks: [taskA, taskB],
      );
      expect(resultDay11, isEmpty);
    });

    test('41) Subtask em conflito: resultado contém a subtask e não adiciona parentId semântico', () {
      final parentA = mkTask(id: 'parentA', locais: ['LOC_1']);
      final subA = mkTask(
        id: 'subA',
        parentId: 'parentA',
        locais: ['LOC_1'],
        executorIds: ['uuid-sub'],
        ganttSegments: [seg(DateTime(2026, 3, 5), DateTime(2026, 3, 15))],
      );
      final taskB = mkTask(
        id: 'taskB',
        locais: ['LOC_2'],
        executorIds: ['uuid-sub'],
        ganttSegments: [seg(DateTime(2026, 3, 8), DateTime(2026, 3, 18))],
      );

      final result = ConflictDetection.resolveConflictTaskIds(
        task: subA,
        day: day10,
        allTasks: [parentA, subA, taskB],
      );

      // Deve conter subA e taskB
      expect(result, containsAll(['subA', 'taskB']));
      // parentA NÃO deve estar no conjunto semântico de conflito (Item 13, 15)
      expect(result.contains('parentA'), isFalse);
    });

    test('Backend First (Item 29): resolve usando eventos de backend quando disponíveis', () {
      final taskA = mkTask(id: 'taskA', executorIds: ['uuid-exec-1']);
      final taskB = mkTask(id: 'taskB', executorIds: ['uuid-exec-1']);

      final eventsBackend = <String, List<ExecutionEventFromBackend>>{
        '2026-03-10': [
          ExecutionEventFromBackend(
            executorId: 'uuid-exec-1',
            executorNome: 'Executor 1',
            day: day10,
            locationKey: 'LOC_1',
            taskId: 'taskA',
            description: 'Task A',
          ),
          ExecutionEventFromBackend(
            executorId: 'uuid-exec-1',
            executorNome: 'Executor 1',
            day: day10,
            locationKey: 'LOC_2',
            taskId: 'taskB',
            description: 'Task B',
          ),
        ],
      };

      final result = ConflictDetection.resolveConflictTaskIds(
        task: taskA,
        day: day10,
        eventsByDayFromBackend: eventsBackend,
        useBackendConflicts: true,
        allTasks: [taskA, taskB],
      );

      expect(result, containsAll(['taskA', 'taskB']));
    });

    test('43) _tasksForTable respeita o filtro oficial de conflitos e preserva contexto de pais', () {
      final parentTask = mkTask(id: 'p1', locais: ['A']);
      final subTask = mkTask(id: 's1', parentId: 'p1', locais: ['A'], executorIds: ['e1']);
      final otherTask = mkTask(id: 't2', locais: ['B'], executorIds: ['e1']);
      final unrelatedTask = mkTask(id: 't3', locais: ['C']);

      final allTasks = [parentTask, subTask, otherTask, unrelatedTask];

      // Simulando a lógica de _tasksForTable:
      final conflictFilterTaskIds = {'s1', 't2'}; // Semântico
      final contextParentIds = <String>{};
      for (final t in allTasks) {
        if (conflictFilterTaskIds.contains(t.id) && t.parentId != null) {
          contextParentIds.add(t.parentId!);
        }
      }
      final filteredTasks = allTasks.where(
        (t) => conflictFilterTaskIds.contains(t.id) || contextParentIds.contains(t.id),
      ).toList();

      expect(filteredTasks.map((t) => t.id).toList(), containsAll(['p1', 's1', 't2']));
      expect(filteredTasks.any((t) => t.id == 't3'), isFalse);
    });
  });
}

