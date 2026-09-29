import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/widgets/team_schedule_view.dart';
import 'package:task2026/widgets/fleet_schedule_view.dart';
import 'package:task2026/widgets/team_management_view.dart';
import 'package:task2026/widgets/fleet_management_view.dart';
import 'package:task2026/services/task_service.dart';
import 'package:task2026/services/executor_service.dart';
import 'package:task2026/services/frota_service.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/models/frota.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';

Widget _buildTestApp(
  Widget child, {
  ThemeData? theme,
  double width = 1280,
  double height = 800,
}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    ),
  );
}

Task _createMockTask({
  required String id,
  required String tarefa,
  String status = 'PROG',
  String executor = 'João Silva',
  String tipo = 'Manutenção',
  DateTime? dataInicio,
  DateTime? dataFim,
}) {
  final start = dataInicio ?? DateTime(2026, 9, 1, 8, 0);
  final end = dataFim ?? DateTime(2026, 9, 5, 17, 0);
  return Task(
    id: id,
    tarefa: tarefa,
    status: status,
    regional: 'Regional Norte',
    divisao: 'Divisão Sul',
    tipo: tipo,
    coordenador: 'Carlos Coord',
    dataInicio: start,
    dataFim: end,
    executor: executor,
    locais: const ['Subestação 01'],
    executores: [executor],
    equipes: const ['Equipe Alpha'],
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await SupabaseConfig.initialize();
    } catch (_) {}
  });

  group('Phase 14B — Resource Schedule Views Tests', () {
    testWidgets('1. Renderiza TeamScheduleView em modo desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        _buildTestApp(
          TeamScheduleView(
            taskService: TaskService(),
            executorService: ExecutorService(),
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            filteredTasks: [
              _createMockTask(id: 'task-1', tarefa: 'Manutenção Preventiva 1'),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TeamScheduleView), findsOneWidget);
    });

    testWidgets('2. Renderiza FleetScheduleView em modo desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        _buildTestApp(
          FleetScheduleView(
            taskService: TaskService(),
            frotaService: FrotaService(),
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            filteredTasks: [
              _createMockTask(id: 'task-2', tarefa: 'Inspeção de Linha'),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FleetScheduleView), findsOneWidget);
    });

    testWidgets('3. Renderiza TeamScheduleView em tema Dark e AXIA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      // Dark theme
      await tester.pumpWidget(
        _buildTestApp(
          TeamScheduleView(
            taskService: TaskService(),
            executorService: ExecutorService(),
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            filteredTasks: const [],
          ),
          theme: TaskFlowTheme.dark(),
        ),
      );
      await tester.pump();
      expect(find.byType(TeamScheduleView), findsOneWidget);

      // AXIA theme
      await tester.pumpWidget(
        _buildTestApp(
          TeamScheduleView(
            taskService: TaskService(),
            executorService: ExecutorService(),
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            filteredTasks: const [],
          ),
          theme: TaskFlowTheme.axia(),
        ),
      );
      await tester.pump();
      expect(find.byType(TeamScheduleView), findsOneWidget);
    });

    testWidgets('4. Renderiza FleetScheduleView em tema Dark e AXIA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      // Dark theme
      await tester.pumpWidget(
        _buildTestApp(
          FleetScheduleView(
            taskService: TaskService(),
            frotaService: FrotaService(),
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            filteredTasks: const [],
          ),
          theme: TaskFlowTheme.dark(),
        ),
      );
      await tester.pump();
      expect(find.byType(FleetScheduleView), findsOneWidget);

      // AXIA theme
      await tester.pumpWidget(
        _buildTestApp(
          FleetScheduleView(
            taskService: TaskService(),
            frotaService: FrotaService(),
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            filteredTasks: const [],
          ),
          theme: TaskFlowTheme.axia(),
        ),
      );
      await tester.pump();
      expect(find.byType(FleetScheduleView), findsOneWidget);
    });

    testWidgets('5. Responsividade — Mobile (390px) e Tablet (768px)', (tester) async {
      // Mobile 390x844
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        _buildTestApp(
          TeamScheduleView(
            taskService: TaskService(),
            executorService: ExecutorService(),
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 10),
            filteredTasks: const [],
          ),
          width: 390,
          height: 844,
        ),
      );
      await tester.pump();
      expect(find.byType(TeamScheduleView), findsOneWidget);

      // Tablet 768x1024
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpWidget(
        _buildTestApp(
          FleetScheduleView(
            taskService: TaskService(),
            frotaService: FrotaService(),
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 10),
            filteredTasks: const [],
          ),
          width: 768,
          height: 1024,
        ),
      );
      await tester.pump();
      expect(find.byType(FleetScheduleView), findsOneWidget);
    });

    testWidgets('6. Renderiza TeamManagementView', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        _buildTestApp(
          TeamManagementView(
            taskService: TaskService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TeamManagementView), findsOneWidget);
    });

    testWidgets('7. Renderiza FleetManagementView', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        _buildTestApp(
          FleetManagementView(
            taskService: TaskService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FleetManagementView), findsOneWidget);
    });
  });
}
