import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/widgets/gantt_chart.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/utils/responsive.dart';
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
  String? parentId,
  String executor = 'João Silva',
  String coordenador = 'Carlos Coord',
  String tipo = 'Manutenção',
  DateTime? dataInicio,
  DateTime? dataFim,
  List<GanttSegment>? segmentos,
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
    coordenador: coordenador,
    dataInicio: start,
    dataFim: end,
    parentId: parentId,
    executor: executor,
    locais: const ['Subestação Norte'],
    executores: [executor],
    equipes: const ['Equipe Alpha'],
    ganttSegments: segmentos ??
        [
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

  group('GanttChart — Phase 14A Widget & Presentation Tests', () {
    testWidgets('1. Renderiza GanttChart com dataset vazio', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final scrollController = ScrollController();
      final horizontalController = ScrollController();

      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: const [],
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 30),
            scrollController: scrollController,
            horizontalController: horizontalController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GanttChart), findsOneWidget);

      scrollController.dispose();
      horizontalController.dispose();
    });

    testWidgets('2. Renderiza tarefas e períodos no GanttChart em escala diária', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final scrollController = ScrollController();
      final horizontalController = ScrollController();

      final tasks = [
        _createMockTask(
          id: 'task-1',
          tarefa: 'Manutenção de Disjuntor 230kV',
          dataInicio: DateTime(2026, 9, 1),
          dataFim: DateTime(2026, 9, 10),
        ),
        _createMockTask(
          id: 'task-2',
          tarefa: 'Inspeção Termográfica SE Norte',
          dataInicio: DateTime(2026, 9, 5),
          dataFim: DateTime(2026, 9, 15),
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 30),
            scale: GanttScale.daily,
            scrollController: scrollController,
            horizontalController: horizontalController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GanttChart), findsOneWidget);

      scrollController.dispose();
      horizontalController.dispose();
    });

    testWidgets('3. Escala semanal e mensal renderizam corretamente', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final scrollController = ScrollController();
      final horizontalController = ScrollController();

      final tasks = [
        _createMockTask(
          id: 'task-1',
          tarefa: 'Revisão Geral Anual',
          dataInicio: DateTime(2026, 9, 1),
          dataFim: DateTime(2026, 9, 30),
        ),
      ];

      // Teste Escala Semanal
      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 10, 31),
            scale: GanttScale.weekly,
            scrollController: scrollController,
            horizontalController: horizontalController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GanttChart), findsOneWidget);

      // Teste Escala Mensal
      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 12, 31),
            scale: GanttScale.monthly,
            scrollController: scrollController,
            horizontalController: horizontalController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GanttChart), findsOneWidget);

      scrollController.dispose();
      horizontalController.dispose();
    });

    testWidgets('4. Contrato Geométrico e Constantes Protegidas', (tester) async {
      // Validar constantes geométricas protegidas
      expect(Responsive.kActivitiesHeaderTopHeight, equals(25.0));
      expect(Responsive.kActivitiesHeaderRowHeight, equals(50.0));
    });

    testWidgets('5. Suporte a Temas (Light, Dark, AXIA)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final scrollController = ScrollController();
      final horizontalController = ScrollController();

      final tasks = [
        _createMockTask(
          id: 'task-theme',
          tarefa: 'Teste de Temas Gantt',
        ),
      ];

      // Light Theme
      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            scrollController: scrollController,
            horizontalController: horizontalController,
          ),
          theme: TaskFlowTheme.light(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GanttChart), findsOneWidget);

      // Dark Theme
      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            scrollController: scrollController,
            horizontalController: horizontalController,
          ),
          theme: TaskFlowTheme.dark(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GanttChart), findsOneWidget);

      // AXIA Theme
      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            scrollController: scrollController,
            horizontalController: horizontalController,
          ),
          theme: TaskFlowTheme.axia(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GanttChart), findsOneWidget);

      scrollController.dispose();
      horizontalController.dispose();
    });

    testWidgets('6. Responsividade em diferentes viewports (Mobile, Tablet, Desktop)', (tester) async {
      final tasks = [
        _createMockTask(
          id: 'task-resp',
          tarefa: 'Teste Responsivo Gantt',
        ),
      ];

      // Mobile 390px
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final scMobile = ScrollController();
      final hcMobile = ScrollController();
      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            scrollController: scMobile,
            horizontalController: hcMobile,
          ),
          width: 390,
          height: 844,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GanttChart), findsOneWidget);
      scMobile.dispose();
      hcMobile.dispose();

      // Tablet 768px
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      final scTablet = ScrollController();
      final hcTablet = ScrollController();
      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            scrollController: scTablet,
            horizontalController: hcTablet,
          ),
          width: 768,
          height: 1024,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GanttChart), findsOneWidget);
      scTablet.dispose();
      hcTablet.dispose();

      // Desktop 1280px
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final scDesktop = ScrollController();
      final hcDesktop = ScrollController();
      await tester.pumpWidget(
        _buildTestApp(
          GanttChart(
            tasks: tasks,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
            scrollController: scDesktop,
            horizontalController: hcDesktop,
          ),
          width: 1280,
          height: 800,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GanttChart), findsOneWidget);
      scDesktop.dispose();
      hcDesktop.dispose();
    });
  });
}
