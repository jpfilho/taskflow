import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/widgets/team_schedule_view.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/services/task_service.dart';
import 'package:task2026/services/executor_service.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';

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

  testWidgets('TeamScheduleView renders with populated data', (tester) async {
    final start = DateTime(2026, 9, 1);
    final end = DateTime(2026, 9, 15);
    final task = Task(
      id: 'task-1',
      tarefa: 'Tarefa Teste',
      status: 'PROG',
      regional: 'R1',
      divisao: 'D1',
      tipo: 'MANUTENCAO',
      coordenador: 'Carlos',
      executor: 'João Silva',
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

    await tester.pumpWidget(
      _buildTestApp(
        TeamScheduleView(
          taskService: TaskService(),
          executorService: ExecutorService(),
          startDate: start,
          endDate: end,
          filteredTasks: [task],
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    print('Pump done!');
  });
}
