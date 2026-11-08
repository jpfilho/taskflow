import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/widgets/common/taskflow_tooltip.dart';
import 'package:task2026/widgets/gantt_chart.dart';
import 'package:task2026/widgets/gantt_segment_widget.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: TaskFlowTheme.light(),
    home: Scaffold(
      body: SizedBox(
        width: 1280,
        height: 800,
        child: child,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await SupabaseConfig.initialize();
    } catch (_) {}
  });

  final day10 = DateTime(2026, 3, 10);
  final start = DateTime(2026, 3, 5);
  final end = DateTime(2026, 3, 15);

  final taskA = Task(
    id: 'taskA',
    tarefa: 'Tarefa A',
    status: 'PROG',
    regional: 'R1',
    divisao: 'D1',
    tipo: 'MANUTENCAO',
    coordenador: 'Coord',
    executor: 'João Silva',
    executorIds: ['exec-1'],
    locais: ['LOC_1'],
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

  testWidgets('GanttSegmentWidget: ação exibe "Filtrar Conflitos" e chama callback com IDs', (tester) async {
    Set<String>? receivedFilterIds;
    bool filterCalled = false;

    final seg = taskA.ganttSegments.first;
    final periods = [
      GanttPeriod(start: day10, end: day10.add(const Duration(days: 1)), label: '10/03'),
    ];

    await tester.pumpWidget(
      _buildTestApp(
        GanttSegmentWidget(
          task: taskA,
          segmentIndex: 0,
          segment: seg,
          normalizedStartDate: start,
          normalizedEndDate: end,
          barWidth: 200,
          dayWidth: 20,
          periods: periods,
          color: Colors.blue,
          textColor: Colors.white,
          conflictDays: [day10],
          conflictTaskIdsByDay: {
            day10: {'taskA', 'taskB'},
          },
          isConflictFilterActive: false,
          onFilterConflictTasks: (ids) {
            filterCalled = true;
            receivedFilterIds = ids;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Encontra o TaskFlowTooltip
    final tooltipFinder = find.byType(TaskFlowTooltip);
    expect(tooltipFinder, findsOneWidget);

    final tooltipWidget = tester.widget<TaskFlowTooltip>(tooltipFinder);
    expect(tooltipWidget.content.actionLabel, equals('Filtrar Conflitos'));

    // Executa a ação simulando o clique no botão do tooltip
    tooltipWidget.content.onAction!();
    await tester.pumpAndSettle();

    expect(filterCalled, isTrue);
    expect(receivedFilterIds, equals({'taskA', 'taskB'}));
  });

  testWidgets('GanttSegmentWidget: quando filtro já está ativo, exibe "Remover Filtro" e chama callback com null', (tester) async {
    Set<String>? receivedFilterIds = {'taskA', 'taskB'};
    bool filterCalled = false;

    final seg = taskA.ganttSegments.first;
    final periods = [
      GanttPeriod(start: day10, end: day10.add(const Duration(days: 1)), label: '10/03'),
    ];

    await tester.pumpWidget(
      _buildTestApp(
        GanttSegmentWidget(
          task: taskA,
          segmentIndex: 0,
          segment: seg,
          normalizedStartDate: start,
          normalizedEndDate: end,
          barWidth: 200,
          dayWidth: 20,
          periods: periods,
          color: Colors.blue,
          textColor: Colors.white,
          conflictDays: [day10],
          conflictTaskIdsByDay: {
            day10: {'taskA', 'taskB'},
          },
          isConflictFilterActive: true, // Já ativo
          onFilterConflictTasks: (ids) {
            filterCalled = true;
            receivedFilterIds = ids;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    final tooltipFinder = find.byType(TaskFlowTooltip);
    expect(tooltipFinder, findsOneWidget);

    final tooltipWidget = tester.widget<TaskFlowTooltip>(tooltipFinder);
    expect(tooltipWidget.content.actionLabel, equals('Remover Filtro'));

    // Executa ação para remover filtro
    tooltipWidget.content.onAction!();
    await tester.pumpAndSettle();

    expect(filterCalled, isTrue);
    // null representa explicitamente "remover filtro" (Itens 8 e 36)
    expect(receivedFilterIds, isNull);
  });
}
