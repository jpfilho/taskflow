import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/services/conflict_service.dart';
import 'package:task2026/utils/conflict_detection.dart';

void main() {
  group('Aceite de Conflitos (Executor e Frota)', () {
    final day10 = DateTime(2026, 10, 10);
    final start = DateTime(2026, 10, 8);
    final end = DateTime(2026, 10, 12);

    Task buildTask(String id, String local, {List<String> execIds = const ['exec-1']}) {
      return Task(
        id: id,
        tarefa: 'Tarefa $id',
        status: 'PROG',
        regional: 'R1',
        divisao: 'D1',
        tipo: 'MANUTENCAO',
        coordenador: 'Coord',
        executor: 'ADÃO - WT',
        executores: const ['ADÃO - WT'],
        executorIds: execIds,
        locais: [local],
        localIds: [local],
        dataInicio: start,
        dataFim: end,
        ganttSegments: [
          GanttSegment(
            tipo: 'BEA',
            tipoPeriodo: 'EXECUCAO',
            label: 'Execução',
            dataInicio: start,
            dataFim: end,
          ),
        ],
      );
    }

    test('canonicalPair e matches são simétricos entre taskA e taskB', () {
      final acc = ConflictAcceptance(
        id: 'acc-1',
        resourceType: 'EXECUTOR',
        resourceId: 'EXEC-1',
        resourceNome: 'ADÃO - WT',
        taskIdA: 'task-a',
        taskIdB: 'task-b',
        acceptedAt: DateTime(2026, 10, 10),
      );

      expect(acc.matches('EXECUTOR', 'exec-1', 'task-a', 'task-b'), isTrue);
      expect(acc.matches('EXECUTOR', 'exec-1', 'task-b', 'task-a'), isTrue);
      expect(acc.matches('FROTA', 'exec-1', 'task-a', 'task-b'), isFalse);
      expect(acc.matches('EXECUTOR', 'exec-1', 'task-a', 'task-c'), isFalse);
      expect(acc.matches('EXECUTOR', 'exec-2', 'task-a', 'task-b'), isFalse);
    });

    test('resolveConflictTaskIds ignora par aceito, mas mantém conflito com 3a tarefa (backend e local)', () {
      final tA = buildTask('task-a', 'LOC_1');
      final tB = buildTask('task-b', 'LOC_2');
      final tC = buildTask('task-c', 'LOC_3');

      final acceptedAB = ConflictAcceptance(
        id: 'acc-ab',
        resourceType: 'EXECUTOR',
        resourceId: 'exec-1',
        resourceNome: 'ADÃO - WT',
        taskIdA: 'task-a',
        taskIdB: 'task-b',
        acceptedAt: DateTime(2026, 10, 10),
      );

      // 1. Apenas A e B com aceite entre A e B => sem conflito
      final onlyAB = ConflictDetection.resolveConflictTaskIds(
        task: tA,
        day: day10,
        allTasks: [tA, tB],
        acceptedConflicts: [acceptedAB],
      );
      expect(onlyAB, isEmpty);

      // 2. A, B e C com aceite apenas entre A e B => conflito entre {A, C} (e B+C no local pois B também colide com C)
      final withC = ConflictDetection.resolveConflictTaskIds(
        task: tA,
        day: day10,
        allTasks: [tA, tB, tC],
        acceptedConflicts: [acceptedAB],
      );
      expect(withC, containsAll(['task-a', 'task-c']));

      // 3. Via backend events: A e B aceitos => vazio
      final dayKey = '2026-10-10';
      final eventsBackend = {
        dayKey: [
          ExecutionEventFromBackend(
            executorId: 'exec-1',
            executorNome: 'ADÃO - WT',
            day: day10,
            locationKey: 'LOC_1',
            taskId: 'task-a',
            description: 'LOC_1 — Tarefa A',
          ),
          ExecutionEventFromBackend(
            executorId: 'exec-1',
            executorNome: 'ADÃO - WT',
            day: day10,
            locationKey: 'LOC_2',
            taskId: 'task-b',
            description: 'LOC_2 — Tarefa B',
          ),
        ],
      };

      final backendAccepted = ConflictDetection.resolveConflictTaskIds(
        task: tA,
        day: day10,
        eventsByDayFromBackend: eventsBackend,
        useBackendConflicts: true,
        acceptedConflicts: [acceptedAB],
      );
      expect(backendAccepted, isEmpty);
    });
  });
}

