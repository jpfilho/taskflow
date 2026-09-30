import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/utils/conflict_detection.dart';

void main() {
  group('ConflictDetection - Validação de Horários', () {
    final day = DateTime(2026, 9, 30);
    const executorId = 'exec-01';

    Task createTask({
      required String id,
      required String tarefa,
      required List<String> localIds,
      required List<String> locais,
      required List<ExecutorPeriod> executorPeriods,
    }) {
      return Task(
        id: id,
        tarefa: tarefa,
        status: 'EXEC',
        regional: 'Região Leste',
        divisao: 'Divisão Norte',
        tipo: 'CORRETIVA',
        coordenador: 'Coordenador 1',
        dataInicio: DateTime(2026, 9, 30),
        dataFim: DateTime(2026, 9, 30),
        localIds: localIds,
        locais: locais,
        executorPeriods: executorPeriods,
      );
    }

    test('Atividades no mesmo dia em locais distintos com horários NÃO sobrepostos NÃO devem gerar conflito', () {
      final task1 = createTask(
        id: 'task-1',
        tarefa: 'Tarefa Manhã',
        localIds: ['local-A'],
        locais: ['Local A'],
        executorPeriods: [
          ExecutorPeriod(
            executorId: executorId,
            executorNome: 'João',
            periods: [
              GanttSegment(
                dataInicio: DateTime(2026, 9, 30, 8, 0),
                dataFim: DateTime(2026, 9, 30, 12, 0),
                label: 'Execução Manhã',
                tipo: 'OUT',
                tipoPeriodo: 'EXECUCAO',
              ),
            ],
          ),
        ],
      );

      final task2 = createTask(
        id: 'task-2',
        tarefa: 'Tarefa Tarde',
        localIds: ['local-B'],
        locais: ['Local B'],
        executorPeriods: [
          ExecutorPeriod(
            executorId: executorId,
            executorNome: 'João',
            periods: [
              GanttSegment(
                dataInicio: DateTime(2026, 9, 30, 13, 0),
                dataFim: DateTime(2026, 9, 30, 17, 0),
                label: 'Execução Tarde',
                tipo: 'OUT',
                tipoPeriodo: 'EXECUCAO',
              ),
            ],
          ),
        ],
      );

      final hasConflict = ConflictDetection.hasConflictOnDayForExecutor(
        [task1, task2],
        day,
        executorId,
      );

      expect(hasConflict, isFalse, reason: 'Horários complementares (08-12h e 13-17h) não devem gerar conflito');
    });

    test('Atividades no mesmo dia em locais distintos com horários SOBREPOSTOS DEVEM gerar conflito', () {
      final task1 = createTask(
        id: 'task-1',
        tarefa: 'Tarefa Manhã Estendida',
        localIds: ['local-A'],
        locais: ['Local A'],
        executorPeriods: [
          ExecutorPeriod(
            executorId: executorId,
            executorNome: 'João',
            periods: [
              GanttSegment(
                dataInicio: DateTime(2026, 9, 30, 8, 0),
                dataFim: DateTime(2026, 9, 30, 14, 0),
                label: 'Execução',
                tipo: 'OUT',
                tipoPeriodo: 'EXECUCAO',
              ),
            ],
          ),
        ],
      );

      final task2 = createTask(
        id: 'task-2',
        tarefa: 'Tarefa Tarde',
        localIds: ['local-B'],
        locais: ['Local B'],
        executorPeriods: [
          ExecutorPeriod(
            executorId: executorId,
            executorNome: 'João',
            periods: [
              GanttSegment(
                dataInicio: DateTime(2026, 9, 30, 13, 0),
                dataFim: DateTime(2026, 9, 30, 17, 0),
                label: 'Execução',
                tipo: 'OUT',
                tipoPeriodo: 'EXECUCAO',
              ),
            ],
          ),
        ],
      );

      final hasConflict = ConflictDetection.hasConflictOnDayForExecutor(
        [task1, task2],
        day,
        executorId,
      );

      expect(hasConflict, isTrue, reason: 'Horários que colidem entre 13h e 14h devem gerar conflito');
    });

    test('Atividades de dia inteiro sem horário específico em locais distintos DEVEM gerar conflito', () {
      final task1 = createTask(
        id: 'task-1',
        tarefa: 'Tarefa Dia Todo Local A',
        localIds: ['local-A'],
        locais: ['Local A'],
        executorPeriods: [
          ExecutorPeriod(
            executorId: executorId,
            executorNome: 'João',
            periods: [
              GanttSegment(
                dataInicio: DateTime(2026, 9, 30, 0, 0),
                dataFim: DateTime(2026, 9, 30, 0, 0),
                label: 'Dia Todo',
                tipo: 'OUT',
                tipoPeriodo: 'EXECUCAO',
              ),
            ],
          ),
        ],
      );

      final task2 = createTask(
        id: 'task-2',
        tarefa: 'Tarefa Dia Todo Local B',
        localIds: ['local-B'],
        locais: ['Local B'],
        executorPeriods: [
          ExecutorPeriod(
            executorId: executorId,
            executorNome: 'João',
            periods: [
              GanttSegment(
                dataInicio: DateTime(2026, 9, 30, 0, 0),
                dataFim: DateTime(2026, 9, 30, 0, 0),
                label: 'Dia Todo',
                tipo: 'OUT',
                tipoPeriodo: 'EXECUCAO',
              ),
            ],
          ),
        ],
      );

      final hasConflict = ConflictDetection.hasConflictOnDayForExecutor(
        [task1, task2],
        day,
        executorId,
      );

      expect(hasConflict, isTrue, reason: 'Duas tarefas de dia todo em locais diferentes continuam em conflito');
    });
  });
}
