import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/widgets/filter_bar.dart';
import 'package:task2026/widgets/team_schedule_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Team Filter Bar and Filtering Tests', () {
    testWidgets('FilterBar teamMode renders EQUIPE, EXECUTOR and COORDENADOR filter fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              teamMode: true,
              teamFilterOptions: {
                'divisoes': ['DIV-01', 'DIV-02'],
                'empresas': ['EMPRESA-A'],
                'equipes': ['Equipe Alfa', 'Equipe Beta'],
                'executores': ['João Silva', 'Maria Santos'],
                'funcoes': ['ELETRICISTA'],
                'matriculas': ['12345'],
                'nomes': ['João Silva', 'Maria Santos'],
                'coordenadores': ['Carlos Coordenador', 'Ana Gerente'],
              },
              onFiltersChanged: (_) {},
              startDate: DateTime(2026, 9, 1),
              endDate: DateTime(2026, 9, 30),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que os campos EQUIPE, EXECUTOR e COORDENADOR estão presentes na tela de equipes
      expect(find.text('EQUIPE'), findsOneWidget);
      expect(find.text('EXECUTOR'), findsOneWidget);
      expect(find.text('COORDENADOR'), findsOneWidget);
    });

    testWidgets('FilterBar teamMode clears EQUIPE, EXECUTOR and COORDENADOR when clear button is pressed', (tester) async {
      Map<String, String?>? emittedFilters;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              teamMode: true,
              initialFilters: {
                'equipe': 'Equipe Alfa',
                'executor': 'João Silva',
                'coordenador': 'Carlos Coordenador',
              },
              teamFilterOptions: {
                'equipes': ['Equipe Alfa', 'Equipe Beta'],
                'executores': ['João Silva', 'Maria Santos'],
                'coordenadores': ['Carlos Coordenador', 'Ana Gerente'],
              },
              onFiltersChanged: (filters) {
                emittedFilters = filters;
              },
              startDate: DateTime(2026, 9, 1),
              endDate: DateTime(2026, 9, 30),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Botão Limpar deve estar visível
      final clearButton = find.textContaining('Limpar');
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Após limpar, campos devem ser null
      expect(emittedFilters?['equipe'], isNull);
      expect(emittedFilters?['executor'], isNull);
      expect(emittedFilters?['coordenador'], isNull);
    });

    test('Team equipe and executor filtering logic retains matching executor rows and tasks', () {
      final executor1 = Executor(
        id: 'exec-1',
        nome: 'João',
        nomeCompleto: 'João Silva',
        funcao: 'ELETRICISTA',
        divisao: 'DIV-01',
        empresa: 'EMPRESA-A',
        ativo: true,
      );
      final executor2 = Executor(
        id: 'exec-2',
        nome: 'Maria',
        nomeCompleto: 'Maria Santos',
        funcao: 'ENCARREGADO',
        divisao: 'DIV-01',
        empresa: 'EMPRESA-A',
        ativo: true,
      );

      final task1 = Task(
        id: 'task-1',
        status: 'CONF',
        statusNome: 'Confirmada',
        regional: 'REG-1',
        divisao: 'DIV-01',
        locais: ['Subestação A'],
        segmento: 'SEG-1',
        equipes: ['Equipe Alfa'],
        tipo: 'MANUTENÇÃO',
        tarefa: 'Manutenção Preventiva',
        executores: ['João Silva'],
        executor: 'João Silva',
        frota: '',
        coordenador: 'Carlos Coordenador',
        si: '',
        dataInicio: DateTime(2026, 9, 1),
        dataFim: DateTime(2026, 9, 2),
        ganttSegments: [],
        executorPeriods: [],
        frotaPeriods: [],
        precisaSi: false,
      );

      final task2 = Task(
        id: 'task-2',
        status: 'CONF',
        statusNome: 'Confirmada',
        regional: 'REG-1',
        divisao: 'DIV-01',
        locais: ['Subestação B'],
        segmento: 'SEG-1',
        equipes: ['Equipe Beta'],
        tipo: 'MANUTENÇÃO',
        tarefa: 'Manutenção Corretiva',
        executores: ['Maria Santos'],
        executor: 'Maria Santos',
        frota: '',
        coordenador: 'Ana Gerente',
        si: '',
        dataInicio: DateTime(2026, 9, 1),
        dataFim: DateTime(2026, 9, 2),
        ganttSegments: [],
        executorPeriods: [],
        frotaPeriods: [],
        precisaSi: false,
      );

      final row1 = ExecutorTaskRow(executor: executor1, tasks: [task1]);
      final row2 = ExecutorTaskRow(executor: executor2, tasks: [task2]);
      final allRows = [row1, row2];

      // 1. Filtrar por Equipe Alfa
      final equipeSet = {'equipe alfa'};
      final filteredByEquipe = allRows.map((row) {
        final matchingTasks = row.tasks.where((t) {
          final taskEquipes = t.equipes.map((eq) => eq.trim().toLowerCase()).toList();
          return equipeSet.any((sel) => taskEquipes.any((te) => te == sel || te.contains(sel) || sel.contains(te)));
        }).toList();

        if (matchingTasks.isEmpty) return null;
        return ExecutorTaskRow(executor: row.executor, tasks: matchingTasks);
      }).whereType<ExecutorTaskRow>().toList();

      expect(filteredByEquipe.length, 1);
      expect(filteredByEquipe.first.executor.id, 'exec-1');
      expect(filteredByEquipe.first.tasks.first.equipes, contains('Equipe Alfa'));

      // 2. Filtrar por Executor Maria
      final executorSet = {'maria santos'};
      final filteredByExecutor = allRows.where((row) {
        final n = (row.executor.nomeCompleto ?? row.executor.nome).trim().toLowerCase();
        final shortName = row.executor.nome.trim().toLowerCase();
        return executorSet.any((sel) => n == sel || shortName == sel || n.contains(sel) || sel.contains(n));
      }).toList();

      expect(filteredByExecutor.length, 1);
      expect(filteredByExecutor.first.executor.id, 'exec-2');
    });
  });
}
