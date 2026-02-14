import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/utils/conflict_detection.dart';

/// Testes da lógica de conflito de agenda (checklist obrigatório).
/// Garante: regra de ouro executorPeriods, só EXECUCAO, status excluídos, locais distintos.
void main() {
  late Task task;

  Task mkTask({
    required String id,
    String status = 'PROG',
    List<String> locais = const [],
    List<String> localIds = const [],
    String? localId,
    String executor = 'E',
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
      dataInicio: dataInicio ?? DateTime(2026, 2, 1),
      dataFim: dataFim ?? DateTime(2026, 2, 28),
      ganttSegments: ganttSegments,
      executorPeriods: executorPeriods,
      parentId: parentId,
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

  group('ConflictDetection', () {
    test('1) Sem conflito - períodos separados (E em A 01-10, E em B 11-20)', () {
      final tasks = [
        mkTask(id: 't1', locais: ['A'], ganttSegments: [seg(DateTime(2026, 2, 1), DateTime(2026, 2, 10))]),
        mkTask(id: 't2', locais: ['B'], ganttSegments: [seg(DateTime(2026, 2, 11), DateTime(2026, 2, 20))]),
      ];
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 5), 'E'), isFalse);
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 15), 'E'), isFalse);
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 10), 'E'), isFalse);
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 11), 'E'), isFalse);
    });

    test('2) Conflito real - sobreposição EXECUCAO (E em A 10-20, E em B 15-25)', () {
      // dataFim exclusivo (dia seguinte 00:00) para interceptar o último dia
      final tasks = [
        mkTask(id: 't1', locais: ['A'], ganttSegments: [seg(DateTime(2026, 2, 10), DateTime(2026, 2, 21))]),
        mkTask(id: 't2', locais: ['B'], ganttSegments: [seg(DateTime(2026, 2, 15), DateTime(2026, 2, 26))]),
      ];
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 15), 'E'), isTrue);
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 20), 'E'), isTrue);
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 10), 'E'), isFalse);
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 25), 'E'), isFalse);
    });

    test('3) Ignorar PLANEJAMENTO/DESLOCAMENTO - só EXECUCAO conta', () {
      final tasks = [
        mkTask(id: 't1', locais: ['A'], ganttSegments: [seg(DateTime(2026, 2, 10), DateTime(2026, 2, 10), 'PLANEJAMENTO')]),
        mkTask(id: 't2', locais: ['B'], ganttSegments: [seg(DateTime(2026, 2, 10), DateTime(2026, 2, 10))]),
      ];
      // Dia 10: A tem só PLANEJAMENTO, B tem EXECUCAO => 1 local com EXECUCAO => sem conflito
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 10), 'E'), isFalse);
    });

    test('4) Status excluídos - tarefa CANC não influencia conflito', () {
      final tasks = [
        mkTask(id: 't1', status: 'CANC', locais: ['A'], ganttSegments: [seg(DateTime(2026, 2, 10), DateTime(2026, 2, 20))]),
        mkTask(id: 't2', locais: ['B'], ganttSegments: [seg(DateTime(2026, 2, 10), DateTime(2026, 2, 20))]),
      ];
      // t1 cancelada não gera evento; só t2 (B) => 1 local => sem conflito
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 15), 'E'), isFalse);
    });

    test('5) Regra de OURO - executorPeriods apenas última semana, início do mês NUNCA gera evento', () {
      // Tarefa longa: ganttSegments EXECUCAO o mês inteiro; executor E com executorPeriods só última semana
      final taskLonga = mkTask(
        id: 't1',
        locais: ['TSD'],
        ganttSegments: [seg(DateTime(2026, 2, 1), DateTime(2026, 3, 1))],
        executorPeriods: [
          ExecutorPeriod(
            executorId: 'e1',
            executorNome: 'E',
            periods: [seg(DateTime(2026, 2, 22), DateTime(2026, 3, 1))],
          ),
        ],
      );
      final tasks = [taskLonga];
      // Início do mês: E tem executorPeriods mas só na última semana => NÃO gera evento
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 7), 'E'), isFalse);
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 1), 'E'), isFalse);
      expect(ConflictDetection.getExecutionEventsForDay(tasks, DateTime(2026, 2, 7)).where((e) => e.executorId == 'E' || e.executorId == 'e1').isEmpty, isTrue);
      // Última semana: gera evento (sem conflito; pode haver 1 ou 2 eventos se E/e1 forem ambos no set)
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 25), 'E'), isFalse);
      final events25 = ConflictDetection.getExecutionEventsForDay(tasks, DateTime(2026, 2, 25));
      expect(events25.length, greaterThanOrEqualTo(1));
      expect(events25.map((e) => e.locationKey).toSet().length, 1);
    });

    test('5b) Regra de OURO - dois locais mas E só em um (executorPeriods) => sem conflito', () {
      // Tarefa 1: TSD, ganttSegments 01-28, E com executorPeriods só 10-14
      // Tarefa 2: BES, E em 07 (outra tarefa)
      // Dia 07: E não deve estar em TSD (executorPeriods não cobre 07) => só BES => sem conflito
      final t1 = mkTask(
        id: 't1',
        locais: ['TSD'],
        ganttSegments: [seg(DateTime(2026, 2, 1), DateTime(2026, 3, 1))],
        executorPeriods: [
          ExecutorPeriod(
            executorId: 'e1',
            executorNome: 'E',
            periods: [seg(DateTime(2026, 2, 10), DateTime(2026, 2, 15))],
          ),
        ],
      );
      final t2 = mkTask(id: 't2', locais: ['BES'], ganttSegments: [seg(DateTime(2026, 2, 6), DateTime(2026, 2, 8))]);
      final tasks = [t1, t2];
      expect(ConflictDetection.hasConflictOnDayForExecutor(tasks, DateTime(2026, 2, 7), 'E'), isFalse);
      final eventsDia7 = ConflictDetection.getExecutionEventsForDay(tasks, DateTime(2026, 2, 7));
      final locaisE = eventsDia7.where((e) => e.executorId == 'E' || e.executorId == 'e1').map((e) => e.locationKey).toSet();
      expect(locaisE.length, 1);
      expect(locaisE.single, 'BES');
    });
  });
}
